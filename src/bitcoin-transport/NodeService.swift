import Foundation
import AsyncAlgorithms
import BitcoinBase
import BitcoinBlockchain
import Logging

/// A peer's unique identifier.
public typealias PeerID = Int

/// Manages connection with state.peers, process incoming messages and sends responses.
public actor NodeService: Sendable {

    public enum Status: Sendable {
        case idle, starting, running, stopping, stopped
    }

    public struct PeerSummary: Sendable {

        init(_ peer: PeerState, id: PeerID) {
            self.id = id
            host = peer.host
            port = peer.port
        }

        public var id: PeerID
        public var host: String
        public var port: Int
    }

    ///  Creates an instance of a bitcoin node service.
    /// - Parameters:
    ///   - blockchain: The bitcoin service actor instance backing this node.
    ///   - network: The type of bitcoin network this node is part of.
    ///   - version: Protocol version number.
    ///   - services: Supported services.
    ///   - feeFilterRate: An arbitrary fee rate by which to filter transactions.
    public init(blockchain: BlockchainService, config: NodeParams, logger: Logger = .init(label: "node"), state: NodeState = .initial) {
        self.blockchain = blockchain
        self.config = config
        self.logger = logger
        self.state = state
        for id in state.peers.keys {
            peerOuts[id] = .init()
        }
    }

    /// The service instance's status.
    public private(set) var status = Status.idle

    /// The bitcoin service actor instance backing this node.
    public let blockchain: BlockchainService

    /// Node configurations parameters.
    public let config: NodeParams

    package let logger: Logger

    public private(set) var state: NodeState

    private var connectionChannels: [AsyncChannel<PeerID>] = []
    private var disconnectionChannels: [AsyncChannel<PeerID>] = []

    public func subscribeToConnections() -> AsyncChannel<PeerID> {
        connectionChannels.append(.init())
        return connectionChannels.last!
    }

    public func subscribeToDisconnections() -> AsyncChannel<PeerID> {
        disconnectionChannels.append(.init())
        return disconnectionChannels.last!
    }

    public func unsubscribe(_ channel: AsyncChannel<PeerID>) {
        channel.finish()
        connectionChannels.removeAll(where: { $0 === channel })
        disconnectionChannels.removeAll(where: { $0 === channel })
    }

    /// Subscription to the bitcoin service's blocks channel.
    private var blocks = AsyncChannel<BlockUpdate>?.none

    /// Subscription to the bitcoin service's transactions channel.
    private var txs = AsyncChannel<Transaction>?.none

    /// IP address as string.
    private var address = IPv6Address?.none

    /// Our port might not exist if peer-to-peer server is down. We can still be conecting with state.peers as a client.
    private var port = Int?.none

    /// Channel for delivering message to state.peers.
    private var peerOuts = [PeerID : AsyncChannel<NetworkMessage>]()

    /// The node's randomly generated identifier (nonce). This is sent with `version` messages.
    private let nonce = UInt64.random(in: UInt64.min ... UInt64.max)

    /// Subscription to new blocks
    private var blockChannels = [AsyncChannel<Block>]()

    /// BIP152
    private var pendingBlockTxs: [Block.ID : [Transaction?]] = [:]

    /// The peer currently downloading headers from; `nil` means the peer has not been selected yet or we are close to the tip and accepting headers from all peers.
    private var headersSyncPeerID: PeerID?

    private var maxPeerID = 0

    // Blocks downloaded and being processed
    private var processingBlocks = Set<Block.ID>()

    public func start() async {
        status = .starting
        let blocks = await blockchain.subscribeToBlocks()
        let txs = await blockchain.subscribeToTransactions()
        self.blocks = blocks
        self.txs = txs
        await withDiscardingTaskGroup { group in
            group.addTask {
                for await (block, status, height) in blocks/*.cancelOnGracefulShutdown()*/ {
                    await self.handleBlockUpdate(block, status: status, height: height)
                }
            }
            group.addTask {
                for await tx in txs/*.cancelOnGracefulShutdown()*/ {
                    await self.handleTx(tx)
                }
            }
        }
        status = .running
    }

    /// Stop this service instance and unsubscribe from blockchain block/transaction updates.
    public func stop() async {
        status = .stopping
        for blockChannel in blockChannels {
            unsubscribe(blockChannel)
        }
        for channel in connectionChannels {
            unsubscribe(channel)
        }
        for channel in disconnectionChannels {
            unsubscribe(channel)
        }
        await withDiscardingTaskGroup { group in
            if let blocks {
                group.addTask {
                    await self.blockchain.unsubscribe(blocks)
                }
            }
            if let txs {
                group.addTask {
                    await self.blockchain.unsubscribe(txs)
                }
            }
        }
        status = .stopped
    }

    /// Called when the peer-to-peer service stops listening for incoming connections.
    public func resetAddress() {
        address = nil
        port = nil
    }

    /// Receive address information from the peer-to-peer service whenever it's actively listening.
    public func setAddress(_ host: String, _ port: Int) {
        self.address = IPv6Address.fromHost(host)
        self.port = port
    }

    /// Send a ping to each of our state.peers. Calling this function will create child tasks.
    public func pingAll() async {
        await withDiscardingTaskGroup {
            for id in state.peers.keys {
                $0.addTask {
                    await self.sendPingTo(id)
                }
            }
        }
    }

    /*
    /// Request headers from peers.
    public func requestHeaders() async {
        let maxHeight = state.peers.values.reduce(-1) { max($0, $1.height) }
        let ourHeight = await blockchain.headers
        guard maxHeight > ourHeight,
              let (id, _) = state.peers.filter({ $0.value.height == maxHeight }).randomElement() else {
            return
        }
        await requestHeaders(id)
    }
     */

    /// Registers a peer with the node. Incoming means we are the listener. Otherwise we are the node initiating the connection.
    public func addPeer(host: String = IPv4Address.empty.description, port: Int = 0, incoming: Bool = true) -> PeerID {
        let id = maxPeerID
        maxPeerID += 1
        state.peers[id] = PeerState(address: IPv6Address.fromHost(host), host: host, port: port, incoming: incoming)
        peerOuts[id] = .init()
        return id
    }

    /// Deregisters all peers.
    public func removeAllPeers(incomingOnly: Bool = false) async {
        for id in state.peers.keys {
            if incomingOnly, !state.peers[id]!.incoming {
                continue
            }
            await removePeer(id)
        }
    }

    public var outgoingPeers: [PeerSummary] {
        state.peers.filter(\.value.outgoing).map {
            .init($0.value, id: $0.key)
        }.sorted {
            $0.id < $1.id
        }
    }

    /// Deregisters a peer and cleans up outbound channels.
    @discardableResult public func removePeer(_ id: PeerID) async -> Bool {
        // Notify subscriber that peer was disconnected
        await withDiscardingTaskGroup { g in
            for channel in disconnectionChannels {
                g.addTask {
                    await channel.send(id)
                }
            }
        }

        guard let _ = state.peers[id] else { return false }
        if headersSyncPeerID == id {
            headersSyncPeerID = nil
        }
        state.peers[id]?.nextPingTask?.cancel()
        state.peers[id]?.checkPongTask?.cancel()
        peerOuts[id]?.finish()
        peerOuts.removeValue(forKey: id)
        state.peers.removeValue(forKey: id)
        return true
    }

    /// Returns a channel for a given peer's outbox. The caller can be notified of new messages generated for this peer.
    public func channel(for id: PeerID) -> AsyncChannel<NetworkMessage> {
        precondition(state.peers[id] != nil)
        return peerOuts[id]!
    }

    /// Subscribe to new blocks from the perspective of this node instance.
    public func subscribeToBlocks() -> AsyncChannel<Block> {
        blockChannels.append(.init())
        return blockChannels.last!
    }

    /// Unsubscribe from new block updates.
    public func unsubscribe(_ channel: AsyncChannel<Block>) {
        channel.finish()
        blockChannels.removeAll(where: { $0 === channel })
    }

    /// Starts the handshake process but only if its an outgoing peer – i.e. we initiated the connection. Generates a child task for delivering the initial version message.
    public func connect(_ id: PeerID) async {
        guard let peer = state.peers[id], peer.outgoing else { return }

        let versionMessage = await makeVersion(for: id)

        enqueue(.version, payload: versionMessage.data, to: id)
        enqueue(.wtxidrelay, to: id)
        enqueue(.sendaddrv2, to: id)
    }

    /// Consume the next message from the outgoing queue.
    public func popMessage(_ id: PeerID) -> NetworkMessage? {
        guard let peer = state.peers[id], !peer.outbox.isEmpty else { return nil }
        return state.peers[id]!.outbox.removeFirst()
    }

    // Sends a ping message to a peer. Creates a new child task.
    public func sendPingTo(_ id: PeerID, useQueue: Bool = false) async {
        guard let peer = state.peers[id], peer.lastPingNonce == nil else { return }

        // Prepare pong check
        state.peers[id]?.checkPongTask = Task.detached { [weak self, pongTolerance = config.pongTolerance] in
            do {
                try await Task.sleep(nanoseconds: UInt64(pongTolerance) * 1_000_000_000)
            } catch { return }
            guard !Task.isCancelled, let self else { return }
            if let peer = await self.state.peers[id], peer.lastPingNonce != nil {
                await peerOuts[id]?.finish() // Trigger disconnection
            }
        }

        // Send ping
        let ping = PingMessage()
        state.peers[id]?.lastPingNonce = ping.nonce
        if useQueue {
            enqueue(.ping, payload: ping.data, to: id)
        } else {
            await send(.ping, payload: ping.data, to: id)
        }
    }

    /// Process an incoming message from a peer. This will sometimes result in sending out one or more messages back to the peer. The function will ultimately create a child task per message sent.
    public func processMessage(_ message: NetworkMessage, from id: PeerID) async throws {
        logger.info("Received \(message.command) (\(message.size)) from \(id)")
        // Postpone the next ping
        state.peers[id]?.nextPingTask?.cancel()
        if let keepAliveFrequency = config.keepAliveFrequency {
            state.peers[id]?.nextPingTask = Task.detached { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: UInt64(keepAliveFrequency) * 1_000_000_000)
                } catch { return }
                guard !Task.isCancelled, let self else { return }
                await self.sendPingTo(id)
            }
        }

        guard let peer = state.peers[id] else { return }

        // First message must always be `version`.
        if peer.version == nil, message.command != .version {
            throw Error.versionMissing
        }

        switch message.command {
        case .version:
            try await processVersion(message, from: id)
        case .wtxidrelay:
            try await processWTXIDRelay(message, from: id)
        case .sendaddrv2:
            try await processSendAddrV2(message, from: id)
        case .verack:
            try await processVerack(message, from: id)
        case .sendcmpct:
            try processSendCompact(message, from: id)
        case .feefilter:
            try processFeeFilter(message, from: id)
        case .ping:
            try await processPing(message, from: id)
        case .pong:
            try processPong(message, from: id)
        case .getheaders:
            try await processGetHeaders(message, from: id)
        case .headers:
            try await processHeaders(message, from: id)
        case .sendheaders:
            try await processSendHeaders(message, from: id)
        case .block:
            try await processBlock(message, from: id)
        case .getdata:
            try await processGetData(message, from: id)
        case .cmpctblock:
            try await processCompactBlock(message, from: id)
        case .inv:
            try await processInventory(message, from: id)
        case .tx:
            try await processTx(message, from: id)
        case .getblocktxn:
            try await processGetBlockTxs(message, from: id)
        case .blocktxn:
            try await processBlockTxs(message, from: id)
        case .getaddr, .addrv2, .notfound, .addr, .getblocks, .unknown:
            break
        }
    }

    private func sendTx(_ tx: Transaction, to id: PeerID) async {
        guard let _ = state.peers[id] else { return }
        let inventoryMessage = InventoryMessage(items: [.init(type: .witnessTx, hash: tx.witnessID)])
        await send(.inv, payload: inventoryMessage.data, to: id)
    }

    private func sendBlock(_ block: Block, to id: PeerID, useQueue: Bool = false) async {
        guard let _ = state.peers[id] else { return }
        let nonce = UInt64.random(in: UInt64.min ... UInt64.max)
        let compactBlockMesssage = CompactBlockMessage(header: block.header, nonce: nonce, txIDs: block.makeShortTxIDs(nonce: nonce, dropIndices: [0]), txs: [.init(index: 0, tx: block.txs[0])])
        if useQueue {
            enqueue(.cmpctblock, payload: compactBlockMesssage.data, to: id)
        } else {
            await send(.cmpctblock, payload: compactBlockMesssage.data, to: id)
        }
    }

    /// Request headers from a specific peer.
    private func requestHeaders(_ id: PeerID) async {
        guard let _ = state.peers[id] else { preconditionFailure() }
        let locatorHashes = await blockchain.blockLocator()
        let getHeaders = GetHeadersMessage(protocolVersion: .latest, locatorHashes: locatorHashes)
        enqueue(.getheaders, payload: getHeaders.data, to: id)
    }

    private func makeVersion(for id: PeerID) async -> VersionMessage {
        guard let peer = state.peers[id] else { preconditionFailure() }

        let lastBlock = await blockchain.height
        return .init(
            protocolVersion: config.version,
            services: config.services,
            receiverServices: peer.version?.services,
            receiverAddress: peer.version?.transmitterAddress,
            receiverPort: peer.version?.transmitterPort,
            transmitterAddress: address,
            transmitterPort: port,
            nonce: nonce,
            startHeight: lastBlock)
    }

    private func requestNextMissingBlocks(_ id: PeerID) async {
        guard let peer = state.peers[id] else { preconditionFailure() }

        let numberOfBlocksToRequest = config.maxInTransitBlocks - peer.inTransitBlocks.count
        guard numberOfBlocksToRequest > 0 else { return }

        let allInTransitBlocks = state.peers.values.reduce(Set<Block.ID>()) {
            $0.union($1.inTransitBlocks)
        }

        let (blockIDs, updatedLastCommonBlock) = await blockchain.findNextBlocksToDownload(bestKnownBlock: peer.bestKnownHeader, lastCommonBlock: peer.lastCommonBlock, count: numberOfBlocksToRequest, exclude: allInTransitBlocks.union(processingBlocks))

        state.peers[id]?.lastCommonBlock = updatedLastCommonBlock

        guard !blockIDs.isEmpty else { return }

        state.peers[id]?.inTransitBlocks.formUnion(blockIDs)

        let ibd = await blockchain.isInitialBlockDownload
        let getData = GetDataMessage(
            items: blockIDs.map { .init(type: ibd ? .witnessBlock : .compactBlock, hash: $0) }
        )
        enqueue(.getdata, payload: getData.data, to: id)
    }

    private func _requestNextMissingBlocks(_ id: PeerID) async {
        guard let peer = state.peers[id] else { preconditionFailure() }

        let numberOfBlocksToRequest = config.maxInTransitBlocks - peer.inTransitBlocks.count
        guard numberOfBlocksToRequest > 0 else { return }

        let allInTransitBlocks = state.peers.values.reduce(Set<Block.ID>()) {
            $0.union($1.inTransitBlocks)
        }

        let blockIDs = await blockchain.nextMissingBlocks(max: numberOfBlocksToRequest, exclude: allInTransitBlocks)

        guard !blockIDs.isEmpty else { return }

        state.peers[id]?.inTransitBlocks.formUnion(blockIDs)

        let ibd = await blockchain.isInitialBlockDownload
        let getData = GetDataMessage(
            items: blockIDs.map { .init(type: ibd ? .witnessBlock : .compactBlock, hash: $0) }
        )
        enqueue(.getdata, payload: getData.data, to: id)
    }

    private func handleBlockUpdate(_ block: Block, status: ValidationStatus, height: Int) async {

        // The following line causes `findNextBlocksToDownload()` to request the same block twice
        // if status == .merkle { processingBlocks.remove(block.id) }

        if status == .active {
            processingBlocks.remove(block.id)

            let ibd = await blockchain.isInitialBlockDownload
            if !ibd {
                await handleBlockRelay(block, height: height)
            }
            // Notify subscribers of new tip
            Task {
                await withDiscardingTaskGroup {
                    for channel in blockChannels {
                        $0.addTask {
                            await channel.send(block)
                        }
                    }
                }
            }
        }
    }

    /// Called when the blockchain notifies us that a new block has been found. Relays blocks to peers.
    private func handleBlockRelay(_ block: Block, height: Int) async {
        await withDiscardingTaskGroup {
            for (id, peer) in state.peers {
                guard !peer.knownBlocks.contains(block.id) else {
                    continue
                }
                $0.addTask {
                    if peer.highBandwidthCompactBlocks {
                        await self.sendBlock(block, to: id)
                    } else {
                        var header = block
                        header.txs = []
                        let items = [header]
                        let headersMessage = HeadersMessage(items: items)
                        if peer.prefersHeaders {
                            await self.send(.headers, payload: headersMessage.data, to: id)
                        } else {
                            let inventoryMessage = InventoryMessage(items: [.init(type: .block, hash:  block.id)]
                            )
                            await self.send(.inv, payload: inventoryMessage.data, to: id)
                        }
                    }
                }
            }
        }
    }

    /// Called when the blockchain notifies us that a new transaction has been accepted into the mempool. Relays transactions to peers.
    private func handleTx(_ tx: Transaction) async {
        await withDiscardingTaskGroup {
            for id in state.peers.keys {
                let peer = state.peers[id]!
                guard !peer.knownTxs.contains(tx.id) else {
                    continue
                }
                $0.addTask {
                    await self.sendTx(tx, to: id)
                }
            }
        }
    }

    /// Sends a message.
    private func send(_ command: MessageCommand, payload: Data = .init(), to id: PeerID) async {
        logger.info("Sending \(command) (\(payload.count)) to \(id)")
        await peerOuts[id]?.send(.init(command, payload: payload, network: config.network))
    }

    /// Queues a message.
    private func enqueue(_ command: MessageCommand, payload: Data = .init(), to id: PeerID) {
        logger.info("Queueing \(command) (\(payload.count)) to \(id)")
        state.peers[id]?.outbox.append(.init(command, payload: payload, network: config.network))
    }

    /// Processes an incoming version message as part of the handshake.
    private func processVersion(_ message: NetworkMessage, from id: PeerID) async throws(Error) {

        // Inbound connection sequence:
        // <- version (we receive the first message from the connecting peer)
        // -> version
        // -> wtxidrelay
        // -> sendaddrv2
        // <- verack
        // -> verack
        // -> sendcmpct
        // -> ping
        // -> getheaders
        // -> feefilter
        // <- pong

        guard let peer = state.peers[id] else { return }

        let ourTime = Date.now

        guard let peerVersion = VersionMessage(message.payload) else {
            preconditionFailure()
        }

        if peerVersion.nonce == nonce {
            throw .connectionToSelf
        }

        if state.peers.values.compactMap(\.version?.nonce).contains(peerVersion.nonce) {
            throw .repeatConnection
        }

        if peerVersion.services.intersection(config.services) != config.services {
            throw .unsupportedServices
        }

        // Inbound connection. Version message is the first message.
        if peerVersion.protocolVersion < config.version {
            throw .unsupportedVersion
        }

        state.peers[id]?.version = peerVersion
        state.peers[id]?.timeDiff = Int(ourTime.timeIntervalSince1970) - Int(peerVersion.timestamp.timeIntervalSince1970)
        state.peers[id]?.reportedHeight = peerVersion.startHeight

        // Outbound connection. Version message is a response to our version.
        if peer.outgoing && peerVersion.protocolVersion > config.version {
            throw .unsupportedVersion
        }

        if peer.incoming {
            let versionMessage = await makeVersion(for: id)
            enqueue(.version, payload: versionMessage.data, to: id)
            enqueue(.wtxidrelay, to: id)
            enqueue(.sendaddrv2, to: id)
        }
    }

    /// BIP339
    private func processWTXIDRelay(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let peer = state.peers[id] else { return }

        // Disconnect state.peers that send a WTXIDRELAY message after VERACK.
        if peer.versionAckReceived {
            // Because we disconnect nodes that don't signal for WTXID relay, this code will never be reached.
            throw Error.requestedWTXIDRelayAfterVerack
        }

        state.peers[id]?.witnessRelayPreferenceReceived = true

        if peer.v2AddressPreferenceReceived {
            enqueue(.verack, to: id)
        }
    }

    /// BIP155
    private func processSendAddrV2(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let peer = state.peers[id] else { return }

        // Disconnect state.peers that send a SENDADDRV2 message after VERACK.
        if peer.versionAckReceived {
            // Because we disconnect nodes that don't ask for v2, this code will never be reached.
            throw Error.requestedV2AddrAfterVerack
        }

        state.peers[id]?.v2AddressPreferenceReceived = true

        if peer.witnessRelayPreferenceReceived {
            enqueue(.verack, to: id)
        }
    }

    private func processVerack(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let peer = state.peers[id] else { return }

        if peer.versionAckReceived {
            // Ignore redundant verack.
            return
        }

        // BIP339
        if !peer.witnessRelayPreferenceReceived {
            throw Error.missingWTXIDRelayPreference
        }

        // BIP155
        if !peer.v2AddressPreferenceReceived {
            throw Error.missingV2AddrPreference
        }

        state.peers[id]?.versionAckReceived = true

        if state.peers[id]!.handshakeComplete {
            // Notify subscriber that this connection has become stable
            await withDiscardingTaskGroup { g in
                for channel in connectionChannels {
                    g.addTask {
                        await channel.send(id)
                    }
                }
            }
            logger.info("Handshake successful.")
        }

        // BIP152 send a burst of supported compact block versions followed by a ping to lock it down.
        enqueue(.sendcmpct, payload: SendCompactMessage(highBandwidth: config.highBandwidthCompactBlocks).data, to: id)
        state.peers[id]?.compactBlocksPreferenceSent = true
        if let pong = peer.pongOnHoldUntilCompactBlocksPreference {
            enqueue(.pong, payload: pong.data, to: id)
            state.peers[id]?.pongOnHoldUntilCompactBlocksPreference = nil
        }
        await sendPingTo(id, useQueue: true)
        await requestHeaders(id)

        // TODO: During IBD set the fee filter to max money. Reset after IBD.
        enqueue(.feefilter, payload: FeeFilterMessage(feeRate: state.feeFilterRate).data, to: id)
    }

    private func processPing(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let peer = state.peers[id] else { return }

        guard let ping = PingMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let pong = PongMessage(nonce: ping.nonce)

        // BIP152 We need to hold the pong until the compact block version was sent.
        if peer.compactBlocksPreferenceSent {
            enqueue(.pong, payload: pong.data, to: id)
        } else {
            state.peers[id]?.pongOnHoldUntilCompactBlocksPreference = pong
        }
    }

    private func processPong(_ message: NetworkMessage, from id: PeerID) throws {

        guard let peer = state.peers[id] else { return }

        guard let pong = PongMessage(message.payload) else {
            throw Error.invalidPayload
        }

        guard let nonce = peer.lastPingNonce, pong.nonce == nonce else {
            throw Error.pingPongMismatch
        }

        state.peers[id]?.lastPingNonce = nil
        state.peers[id]?.checkPongTask?.cancel()

        // BIP152: Lock compact block version on first pong.

        if peer.compactBlocksVersionLocked { return }

        guard let compactBlocksVersion = peer.compactBlocksVersion, compactBlocksVersion >= Self.minCompactBlocksVersion else {
            throw Error.unsupportedCompactBlocksVersion
        }
        state.peers[id]?.compactBlocksVersionLocked = true
    }

    /// BIP152
    private func processSendCompact(_ message: NetworkMessage, from id: PeerID) throws {
        guard let peer = state.peers[id] else { return }

        guard let sendCompact = SendCompactMessage(message.payload) else {
            throw Error.invalidPayload
        }

        // We let the negotiation play out for versions lower than our max supported. When version is finally locked we will enforce our minimum supported version as well.
        if peer.compactBlocksVersion == nil, sendCompact.version <= Self.maxCompactBlocksVersion {
            state.peers[id]?.highBandwidthCompactBlocks = sendCompact.highBandwidth
            state.peers[id]?.compactBlocksVersion = sendCompact.version
        }
    }

    /// BIP133
    private func processFeeFilter(_ message: NetworkMessage, from id: PeerID) throws {
        guard let feeFilter = FeeFilterMessage(message.payload) else {
            logger.error("Could not parse fee filter message")
            throw Error.invalidPayload
        }

        state.peers[id]?.feeFilterRate = feeFilter.feeRate
    }

    private func processGetHeaders(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { return }

        guard let getHeaders = GetHeadersMessage(message.payload) else {
            logger.error("Could not parse get headers message")
            throw Error.invalidPayload
        }

        logger.info("getheaders: \(getHeaders.locatorHashes.first?.hex ?? "-")")
        let headers = await blockchain.headers(matching: getHeaders.locatorHashes)
        let headersMessage = HeadersMessage(items: headers)
        enqueue(.headers, payload: headersMessage.data, to: id)
    }

    private func processHeaders(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { return }

        guard let headersMessage = HeadersMessage(message.payload) else {
            throw Error.invalidPayload
        }

        state.peers[id]!.registerKnownBlocks(headersMessage.items.map(\.id))

        let headerProcessingResult: HeaderProcessingResult
        do {
            headerProcessingResult = try await blockchain.processHeaders(headersMessage.items)
        } catch {
            logger.error("Issue processing headers from peer \(id):\n\(error)")
            // state.peers[id]?.height = await blockchain.height
            return
        }
        updatePeer(id, with: headerProcessingResult)

        // If we are close to the tip (24 hours) we allow parallel
        if await blockchain.hasRecentHeader {
            headersSyncPeerID = nil
        } else if headersSyncPeerID == nil {
            headersSyncPeerID = id
        }

        if headersMessage.moreItems {
            guard headersSyncPeerID == nil || headersSyncPeerID == id else {
                return
            }
            await requestHeaders(id)
        } else {
            let headers = await blockchain.headers // Just the total
            logger.info("All headers downloaded from peer \(id): \(headers).")

            // BIP130 delaying `sendheaders` until we don't need more headers. Do this for this particular peer.
            enqueue(.sendheaders, to: id)
            state.peers[id]!.allHeadersDownloaded = true

            var doneSyncingHeaders = true
            for peerID in state.peers.keys {
                guard peerID != id, !state.peers[peerID]!.allHeadersDownloaded else {
                    continue
                }
                doneSyncingHeaders = false
                await requestHeaders(peerID)
                break
            }
            if doneSyncingHeaders {
                logger.info("All headers downloaded from all peers.")
                await requestNextMissingBlocks(id)
            }
        }
    }

    private func updatePeer(_ id: PeerID, with headerProcessingResult: HeaderProcessingResult) {

        // Update peer's held headers (non-connecting)
        state.peers[id]!.heldHeaders.formUnion(headerProcessingResult.heldHeaders)

        // Update bestKnownHeader for peer
        let maxChainworkRef = headerProcessingResult.headerRefs.max(by: { $0.chainwork < $1.chainwork })

        if let maxChainworkRef {
            if let bestKnownHeader = state.peers[id]!.bestKnownHeader {
                if maxChainworkRef.chainwork > bestKnownHeader.chainwork {
                    state.peers[id]!.bestKnownHeader = maxChainworkRef
                }
            } else {
                state.peers[id]!.bestKnownHeader = maxChainworkRef
            }
        }

        // Remove connected headers from peers' held list and update best known header for each peer
        for connectedHeader in headerProcessingResult.connectedHeaders {
            let connectedHeaderID = connectedHeader.header.id
            for (peerID, peer) in state.peers {
                if !peer.heldHeaders.contains(connectedHeaderID) {
                    continue
                }
                state.peers[peerID]!.heldHeaders.remove(connectedHeaderID)
                if let bestKnownHeader = peer.bestKnownHeader {
                    if connectedHeader.chainwork > bestKnownHeader.chainwork {
                        state.peers[id]!.bestKnownHeader = connectedHeader
                    }
                } else {
                    state.peers[id]!.bestKnownHeader = connectedHeader
                }
            }
        }
    }

    private func processSendHeaders(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { return }
        state.peers[id]!.prefersHeaders = true
    }

    private func processBlock(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let block = try? Block(message.payload) else {
            throw Error.invalidPayload
        }

        logger.debug("Received block \(block.idHex)")

        state.peers[id]!.registerKnownBlocks([block.id])
        state.peers[id]?.inTransitBlocks.remove(block.id)

        processingBlocks.insert(block.id)
        let headerProcessingResult = try await blockchain.processBlock(block, immediate: false)

        updatePeer(id, with: headerProcessingResult)

        // TODO: Clean up commented out single-peer block download code
        /*
         // Code for only requesting blocks from the same peer
        if state.peers[id]!.inTransitBlocks == 0 {
            await requestNextMissingBlocks(id)
        }
         */

        // Code for requesting blocks from multiple peers
        let currentChainwork = await blockchain.currentChainwork
        var lowestInTransitBlocks = config.maxInTransitBlocks
        var selectedPeerID = PeerID?.none
        // Looking for the peer which has the least amount of in transit blocks
        for (id, peer) in state.peers {
            let inTransitBlocks = peer.inTransitBlocks.count

            guard let bestKnownHeader = peer.bestKnownHeader, bestKnownHeader.chainwork > currentChainwork else {
                continue
            }
            // TODO: temporarilly only use peers with 0 blocks in transit (other wise breaks BlockSyncTests) - also related https://github.com/swift-bitcoin/swift-bitcoin/issues/530 and https://github.com/swift-bitcoin/swift-bitcoin/issues/531
            if inTransitBlocks < lowestInTransitBlocks, inTransitBlocks == 0 {
                lowestInTransitBlocks = inTransitBlocks
                selectedPeerID = id
            }
        }
        if let selectedPeerID {
            await requestNextMissingBlocks(selectedPeerID)
        } else {
            logger.debug("All peers have reached their maximum in transit blocks")
        }
    }

    private func processGetData(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let getDataMessage = GetDataMessage(message.payload) else {
            throw Error.invalidPayload
        }

        if await blockchain.isInitialBlockDownload {
            return
        }

        let compactBlockHashes = getDataMessage.items.filter { $0.type == .compactBlock }.map { $0.hash }
        if !compactBlockHashes.isEmpty {
            let blocks = await blockchain.blocks(matching: compactBlockHashes)
            for block in blocks {
                await sendBlock(block, to: id, useQueue: true)
            }
        }

        let blockHashes = getDataMessage.items.filter { $0.type == .witnessBlock }.map { $0.hash }
        if !blockHashes.isEmpty {
            let blocks = await blockchain.blocks(matching: blockHashes)

            for block in blocks {
                enqueue(.block, payload: block.data, to: id)
            }
        }

        let txHashes = getDataMessage.items.filter { $0.type == .witnessTx }.map { $0.hash }
        if !txHashes.isEmpty {
            let txs = await blockchain.transactions(matching: txHashes)
            for tx in txs {
                enqueue(.tx, payload: tx.data, to: id)
            }
        }
    }

    private func processInventory(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let inventoryMessage = InventoryMessage(message.payload) else {
            throw Error.invalidPayload
        }

        var blockIDs = [Block.ID]()
        var txIDs = [Transaction.ID]()
        for item in inventoryMessage.items {
            if item.type == .witnessBlock {
                blockIDs.append(item.hash)
            }
            if item.type == .witnessTx {
                txIDs.append(item.hash)
            }
        }
        var items = [InventoryItem]()
        if await !blockchain.isInitialBlockDownload {
            for txID in await blockchain.missingTransactions(matching: txIDs) {
                items.append(.init(type: .witnessTx, hash: txID))
            }
        }
        for blockID in await blockchain.missingBlocks(matching: blockIDs) {
            items.append(.init(type: .witnessBlock, hash: blockID))
        }
        let getData = GetDataMessage(items: items)
        enqueue(.getdata, payload: getData.data, to: id)
    }

    private func processTx(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        let tx: Transaction
        do {
            tx = try Transaction(message.payload)
        } catch {
            throw Error.invalidPayload
        }
        if await blockchain.isInitialBlockDownload {
            return
        }
        state.peers[id]!.registerKnownTxs([tx.id])
        do {
            try await blockchain.addTransaction(tx)
        } catch {
            logger.warning("tx rejected by mempool: \(tx.idHex)")
        }
    }

    private func processCompactBlock(_ message: NetworkMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let compactBlockMessage = CompactBlockMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let header = compactBlockMessage.header
        state.peers[id]!.registerKnownBlocks([header.id])

        let txCount = compactBlockMessage.txIDs.count + compactBlockMessage.txs.count
        var txs: [Transaction?] = .init(repeating: nil, count: txCount)

        for prefilled in compactBlockMessage.txs {
            txs[prefilled.index] = prefilled.tx
        }

        let mempoolTxs = await blockchain.mempoolTransactions(shortIDs: compactBlockMessage.txIDs, header: compactBlockMessage.header, nonce: compactBlockMessage.nonce)

        var j = 0
        for i in txs.indices {
            if txs[i] == nil {
                if mempoolTxs[j] != nil {
                    txs[i] = mempoolTxs[j]
                }
                j += 1
            }
        }

        let missingTxIndices = txs.enumerated().compactMap { i, tx in
            if tx == nil { i } else { nil }
        }

        let headerProcessingResult: HeaderProcessingResult
        if missingTxIndices.isEmpty {
            var block = compactBlockMessage.header
            block.txs = txs.compactMap { $0 }
            precondition(block.txs.count == txs.count)
            headerProcessingResult = try await blockchain.processBlock(block, immediate: true) // TODO: Immediate = false to not block
        } else {
             headerProcessingResult = try await blockchain.processHeaders([header])

            pendingBlockTxs[header.id] = txs
            let getBlockTxs = GetBlockTransactionsMessage(blockHash: compactBlockMessage.header.id, txIndices: missingTxIndices)
            enqueue(.getblocktxn, payload: getBlockTxs.data, to: id)
        }
        updatePeer(id, with: headerProcessingResult)
    }

    private func processGetBlockTxs(_ message: NetworkMessage, from id: PeerID) async throws(Error) {
        guard let _ = state.peers[id] else { preconditionFailure() }
        guard let getBlockTxsMessage = GetBlockTransactionsMessage(message.payload) else {
            throw .invalidPayload
        }
        guard let block = await blockchain.block(for: getBlockTxsMessage.blockHash) else {
            throw .blockNotFound
        }
        var txs = [Transaction]()
        for i in getBlockTxsMessage.txIndices {
            txs.append(block.txs[i])
        }
        let blockTxs = BlockTransactionsMessage(blockHash: block.id, txs: txs)
        enqueue(.blocktxn, payload: blockTxs.data, to: id)
    }

    private func processBlockTxs(_ message: NetworkMessage, from id: PeerID) async throws(Error) {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let blockTxsMessage = BlockTransactionsMessage(message.payload) else {
            throw .invalidPayload
        }

        guard var pendingBlockTxs = pendingBlockTxs[blockTxsMessage.blockHash] else { return }
        self.pendingBlockTxs[blockTxsMessage.blockHash] = nil

        var j = 0
        for i in pendingBlockTxs.indices {
            if pendingBlockTxs[i] == nil {
                pendingBlockTxs[i] = blockTxsMessage.txs[j]
                j += 1
            }
        }

        guard var block = await blockchain.header(for: blockTxsMessage.blockHash) else {
            throw .blockNotFound
        }
        block.txs = pendingBlockTxs.compactMap { $0 }
        let headerProcessingResult: HeaderProcessingResult
        do {
            headerProcessingResult = try await blockchain.processBlock(block, immediate: true) // TODO: Immediate = false to not block
        } catch {
            throw .invalidBlock
        }
        updatePeer(id, with: headerProcessingResult)
    }

    static let minCompactBlocksVersion = 2
    static let maxCompactBlocksVersion = 2
}

