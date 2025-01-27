import Foundation
import AsyncAlgorithms
import BitcoinBase
import BitcoinBlockchain

public typealias PeerID = UUID

/// Manages connection with state.peers, process incoming messages and sends responses.
public actor NodeService: Sendable {

    ///  Creates an instance of a bitcoin node service.
    /// - Parameters:
    ///   - blockchain: The bitcoin service actor instance backing this node.
    ///   - network: The type of bitcoin network this node is part of.
    ///   - version: Protocol version number.
    ///   - services: Supported services.
    ///   - feeFilterRate: An arbitrary fee rate by which to filter transactions.
    public init(blockchain: BlockchainService, config: NodeConfig = .default, state: NodeState = .initial) {
        self.blockchain = blockchain
        self.config = config
        self.state = state
        for id in state.peers.keys {
            peerOuts[id] = .init()
        }
    }

    /// The bitcoin service actor instance backing this node.
    public let blockchain: BlockchainService

    public let config: NodeConfig
    public var state: NodeState

    /// Subscription to the bitcoin service's blocks channel.
    public var blocks = AsyncChannel<TxBlock>?.none

    /// Subscription to the bitcoin service's transactions channel.
    public var txs = AsyncChannel<BitcoinTx>?.none

    /// IP address as string.
    var address = IPv6Address?.none

    /// Our port might not exist if peer-to-peer server is down. We can still be conecting with state.peers as a client.
    var port = Int?.none

    /// Channel for delivering message to state.peers.
    var peerOuts = [UUID : AsyncChannel<BitcoinMessage>]()

    /// The node's randomly generated identifier (nonce). This is sent with `version` messages.
    let nonce = UInt64.random(in: UInt64.min ... UInt64.max)

    /// Called when the peer-to-peer service stops listening for incoming connections.
    public func resetAddress() {
        address = .none
        port = .none
    }

    /// Receive address information from the peer-to-peer service whenever it's actively listening.
    public func setAddress(_ host: String, _ port: Int) {
        self.address = IPv6Address.fromHost(host)
        self.port = port
    }

    public func start() async {
        let blocks = await blockchain.subscribeToBlocks()
        let txs = await blockchain.subscribeToTxs()
        self.blocks = blocks
        self.txs = txs
        await withDiscardingTaskGroup { group in
            group.addTask {
                for await block in blocks/*.cancelOnGracefulShutdown()*/ {
                    await self.handleBlock(block)
                }
            }
            group.addTask {
                for await tx in txs/*.cancelOnGracefulShutdown()*/ {
                    await self.handleTx(tx)
                }
            }
        }
    }

    /// Called when the blockchain notifies us that a new block has been found. Relays blocks to peers.
    private func handleBlock(_ block: TxBlock) async {
        await withDiscardingTaskGroup {
            for id in state.peers.keys {
                let peer = state.peers[id]!
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
                        await self.send(.headers, payload: headersMessage.data, to: id)
                    }
                }
            }
        }
    }

    /// Called when the blockchain notifies us that a new transaction has been accepted into the mempool. Relays transactions to peers.
    private func handleTx(_ tx: BitcoinTx) async {
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

    /// We unsubscribe from Bitcoin service's blocks.
    public func stop() async {
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

    /// Request headers from peers.
    public func requestHeaders() async {
        let maxHeight = state.peers.values.reduce(-1) { max($0, $1.height) }
        let ourHeight = await blockchain.blocks.count - 1
        guard maxHeight > ourHeight,
              let (id, _) = state.peers.filter({ $0.value.height == maxHeight }).randomElement() else {
            return
        }
        await requestHeaders(id)
    }

    /// Request headers from a specific peer.
    func requestHeaders(_ id: PeerID) async {
        guard let _ = state.peers[id] else { preconditionFailure() }
        let locatorHashes = await blockchain.makeBlockLocator()
        let getHeaders = GetHeadersMessage(protocolVersion: .latest, locatorHashes: locatorHashes)
        enqueue(.getheaders, payload: getHeaders.data, to: id)
    }

    func requestNextMissingBlocks(_ id: PeerID) async {
        guard let peer = state.peers[id] else { preconditionFailure() }

        let numberOfBlocksToRequest = config.maxInTransitBlocks - peer.inTransitBlocks
        guard numberOfBlocksToRequest > 0 else { return }

        let blockIDs = await blockchain.getNextMissingBlocks(numberOfBlocksToRequest)

        guard !blockIDs.isEmpty else { return }

        state.peers[id]?.inTransitBlocks += blockIDs.count

        let getData = GetDataMessage(
            items: blockIDs.map { .init(type: state.ibdComplete ? .compactBlock : .witnessBlock, hash: $0) }
        )
        enqueue(.getdata, payload: getData.data, to: id)
    }

    /// Registers a peer with the node. Incoming means we are the listener. Otherwise we are the node initiating the connection.
    public func addPeer(host: String = IPv4Address.empty.description, port: Int = 0, incoming: Bool = true) async -> UUID {
        let id = PeerID()
        state.peers[id] = PeerState(address: IPv6Address.fromHost(host), port: port, incoming: incoming)
        peerOuts[id] = .init()
        return id
    }

    /// Deregisters a peer and cleans up outbound channels.
    public func removePeer(_ id: PeerID) {
        state.peers[id]?.nextPingTask?.cancel()
        state.peers[id]?.checkPongTask?.cancel()
        peerOuts[id]?.finish()
        peerOuts.removeValue(forKey: id)
        state.peers.removeValue(forKey: id)
    }

    /// Returns a channel for a given peer's outbox. The caller can be notified of new messages generated for this peer.
    public func getChannel(for id: PeerID) -> AsyncChannel<BitcoinMessage> {
        precondition(state.peers[id] != nil)
        return peerOuts[id]!
    }

    func makeVersion(for id: PeerID) async -> VersionMessage {
        guard let peer = state.peers[id] else { preconditionFailure() }

        let lastBlock = await blockchain.tip - 1
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

    /// Starts the handshake process but only if its an outgoing peer – i.e. we initiated the connection. Generates a child task for delivering the initial version message.
    public func connect(_ id: PeerID) async {
        guard let peer = state.peers[id], peer.outgoing else { return }

        let versionMessage = await makeVersion(for: id)

        enqueue(.version, payload: versionMessage.data, to: id)
        enqueue(.wtxidrelay, to: id)
        enqueue(.sendaddrv2, to: id)
    }

    func sendTx(_ tx: BitcoinTx, to id: PeerID) async {
        guard let _ = state.peers[id] else { return }
        let inventoryMessage = InventoryMessage(items: [.init(type: .witnessTx, hash: tx.witnessID)])
        await send(.inv, payload: inventoryMessage.data, to: id)
    }

    func sendBlock(_ block: TxBlock, to id: PeerID, useQueue: Bool = false) async {
        guard let _ = state.peers[id] else { return }
        let nonce = UInt64.random(in: UInt64.min ... UInt64.max)
        let compactBlockMesssage = CompactBlockMessage(header: block.header, nonce: nonce, txIDs: block.makeShortTxIDs(nonce: nonce), txs: [.init(index: 0, tx: block.txs[0])])
        if useQueue {
            enqueue(.cmpctblock, payload: compactBlockMesssage.data, to: id)
        } else {
            await send(.cmpctblock, payload: compactBlockMesssage.data, to: id)
        }
    }

    // Sends a ping message to a peer. Creates a new child task.
    func sendPingTo(_ id: PeerID, useQueue: Bool = false) async {
        guard let peer = state.peers[id], peer.lastPingNonce == .none else { return }

        // Prepare pong check
        let pongTolerance = config.pongTolerance
        state.peers[id]?.checkPongTask = Task.detached { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(pongTolerance) * 1_000_000_000)
            } catch { return }
            guard !Task.isCancelled, let self else { return }
            if let peer = await self.state.peers[id], peer.lastPingNonce != .none {
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

    public func popMessage(_ id: PeerID) -> BitcoinMessage? {
        guard let peer = state.peers[id], !peer.outbox.isEmpty else { return .none }
        return state.peers[id]!.outbox.removeFirst()
    }

    /// Process an incoming message from a peer. This will sometimes result in sending out one or more messages back to the peer. The function will ultimately create a child task per message sent.
    public func processMessage(_ message: BitcoinMessage, from id: PeerID) async throws {

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
        if peer.version == .none, message.command != .version {
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

    /// Sends a message.
    private func send(_ command: MessageCommand, payload: Data = .init(), to id: PeerID) async {
        await peerOuts[id]?.send(.init(command, payload: payload, network: config.network))
    }

    /// Queues a message.
    private func enqueue(_ command: MessageCommand, payload: Data = .init(), to id: PeerID) {
        state.peers[id]?.outbox.append(.init(command, payload: payload, network: config.network))
    }

    /// Processes an incoming version message as part of the handshake.
    private func processVersion(_ message: BitcoinMessage, from id: PeerID) async throws(Error) {

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

        if peerVersion.services.intersection(config.services) != config.services {
            throw .unsupportedServices
        }

        // Inbound connection. Version message is the first message.
        if peerVersion.protocolVersion < config.version {
            throw .unsupportedVersion
        }

        state.peers[id]?.version = peerVersion
        state.peers[id]?.timeDiff = Int(ourTime.timeIntervalSince1970) - Int(peerVersion.timestamp.timeIntervalSince1970)
        state.peers[id]?.height = peerVersion.startHeight

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
    private func processWTXIDRelay(_ message: BitcoinMessage, from id: PeerID) async throws {
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
    private func processSendAddrV2(_ message: BitcoinMessage, from id: PeerID) async throws {
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

    private func processVerack(_ message: BitcoinMessage, from id: PeerID) async throws {
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
            print("Handshake successful.")
        }

        // BIP152 send a burst of supported compact block versions followed by a ping to lock it down.
        enqueue(.sendcmpct, payload: SendCompactMessage(highBandwidth: config.highBandwidthCompactBlocks).data, to: id)
        state.peers[id]?.compactBlocksPreferenceSent = true
        if let pong = peer.pongOnHoldUntilCompactBlocksPreference {
            enqueue(.pong, payload: pong.data, to: id)
            state.peers[id]?.pongOnHoldUntilCompactBlocksPreference = .none
        }
        await sendPingTo(id, useQueue: true)
        await requestHeaders(id)
        enqueue(.feefilter, payload: FeeFilterMessage(feeRate: state.feeFilterRate).data, to: id)
    }

    private func processPing(_ message: BitcoinMessage, from id: PeerID) async throws {
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

    private func processPong(_ message: BitcoinMessage, from id: PeerID) throws {

        guard let peer = state.peers[id] else { return }

        guard let pong = PongMessage(message.payload) else {
            throw Error.invalidPayload
        }

        guard let nonce = peer.lastPingNonce, pong.nonce == nonce else {
            throw Error.pingPongMismatch
        }

        state.peers[id]?.lastPingNonce = .none
        state.peers[id]?.checkPongTask?.cancel()

        // BIP152: Lock compact block version on first pong.

        if peer.compactBlocksVersionLocked { return }

        guard let compactBlocksVersion = peer.compactBlocksVersion, compactBlocksVersion >= Self.minCompactBlocksVersion else {
            throw Error.unsupportedCompactBlocksVersion
        }
        state.peers[id]?.compactBlocksVersionLocked = true
    }

    /// BIP152
    private func processSendCompact(_ message: BitcoinMessage, from id: PeerID) throws {
        guard let peer = state.peers[id] else { return }

        guard let sendCompact = SendCompactMessage(message.payload) else {
            throw Error.invalidPayload
        }

        // We let the negotiation play out for versions lower than our max supported. When version is finally locked we will enforce our minimum supported version as well.
        if peer.compactBlocksVersion == .none, sendCompact.version <= Self.maxCompactBlocksVersion {
            state.peers[id]?.highBandwidthCompactBlocks = sendCompact.highBandwidth
            state.peers[id]?.compactBlocksVersion = sendCompact.version
        }
    }

    /// BIP133
    private func processFeeFilter(_ message: BitcoinMessage, from id: PeerID) throws {
        guard let feeFilter = FeeFilterMessage(message.payload) else {
            throw Error.invalidPayload
        }

        state.peers[id]?.feeFilterRate = feeFilter.feeRate
    }

    private func processGetHeaders(_ message: BitcoinMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { return }

        guard let getHeaders = GetHeadersMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let headers = await blockchain.findHeaders(using: getHeaders.locatorHashes)
        let headersMessage = HeadersMessage(items: headers)
        enqueue(.headers, payload: headersMessage.data, to: id)
    }

    private func processHeaders(_ message: BitcoinMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { return }

        guard let headersMessage = HeadersMessage(message.payload) else {
            throw Error.invalidPayload
        }

        // TODO: Improve IBD logic. If multiple blocks need to be sync'ed, then we go into block download mode.
        if !state.ibdComplete, headersMessage.items.isEmpty, await blockchain.synchronized {
            state.ibdComplete = true
        }

        state.peers[id]!.registerKnownBlocks(headersMessage.items.map(\.id))

        do {
            try await blockchain.processHeaders(headersMessage.items)
        } catch {
            state.peers[id]?.height = await blockchain.blocks.count - 1
        }

        if headersMessage.moreItems {
            await requestHeaders(id)
        }

        await requestNextMissingBlocks(id)
    }

    func processBlock(_ message: BitcoinMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let block = TxBlock(message.payload) else {
            throw Error.invalidPayload
        }

        try await blockchain.processBlock(block)

        state.peers[id]?.inTransitBlocks -= 1

        if !state.ibdComplete, await blockchain.synchronized {
            state.ibdComplete = true
        }

        if state.peers[id]!.inTransitBlocks == 0 {
            await requestNextMissingBlocks(id)
        }
    }

    func processGetData(_ message: BitcoinMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let getDataMessage = GetDataMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let compactBlockHashes = getDataMessage.items.filter { $0.type == .compactBlock }.map { $0.hash }
        if !compactBlockHashes.isEmpty {
            let blocks = await blockchain.getBlocks(compactBlockHashes)
            for block in blocks {
                await sendBlock(block, to: id, useQueue: true)
            }
        }

        let blockHashes = getDataMessage.items.filter { $0.type == .witnessBlock }.map { $0.hash }
        if !blockHashes.isEmpty {
            let blocks = await blockchain.getBlocks(blockHashes)

            for block in blocks {
                enqueue(.block, payload: block.data, to: id)
            }
        }

        let txHashes = getDataMessage.items.filter { $0.type == .witnessTx }.map { $0.hash }
        if !txHashes.isEmpty {
            let txs = await blockchain.getTxs(txHashes)
            for tx in txs {
                enqueue(.tx, payload: tx.binaryData, to: id)
            }
        }
    }

    func processInventory(_ message: BitcoinMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let inventoryMessage = InventoryMessage(message.payload) else {
            throw Error.invalidPayload
        }

        var blockIDs = [BlockID]()
        var txIDs = [TxID]()
        for item in inventoryMessage.items {
            if item.type == .witnessBlock {
                blockIDs.append(item.hash)
            }
            if item.type == .witnessTx {
                txIDs.append(item.hash)
            }
        }
        var items = [InventoryItem]()
        for txID in await blockchain.calculateMissingTxs(ids: txIDs) {
            items.append(.init(type: .witnessTx, hash: txID))
        }
        for blockID in await blockchain.calculateMissingBlocks(ids: blockIDs) {
            items.append(.init(type: .witnessBlock, hash: blockID))
        }
        let getData = GetDataMessage(items: items)
        enqueue(.getdata, payload: getData.data, to: id)
    }

    func processTx(_ message: BitcoinMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        let tx: BitcoinTx
        do {
            tx = try BitcoinTx(binaryData: message.payload)
        } catch {
            throw Error.invalidPayload
        }
        state.peers[id]!.registerKnownTxs([tx.id])
        try await blockchain.addTx(tx)
    }

    func processCompactBlock(_ message: BitcoinMessage, from id: PeerID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let compactBlockMessage = CompactBlockMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let header = compactBlockMessage.header
        try await blockchain.processHeaders([header])
        state.peers[id]!.registerKnownBlocks([header.id])

        var txs = await blockchain.findMempoolTxs(shortIDs: compactBlockMessage.txIDs, header: compactBlockMessage.header, nonce: compactBlockMessage.nonce)
        for prefilled in compactBlockMessage.txs {
            txs[prefilled.index] = prefilled.tx
        }

        let missingTxIndices = txs.enumerated().compactMap {
            if $0.element == .none { $0.offset } else { .none }
        }

        if missingTxIndices.isEmpty {
            var block = compactBlockMessage.header
            block.txs = txs.compactMap { $0 }
            try await blockchain.processBlock(block)
        } else {
            state.peers[id]?.pendingBlockTxs = txs
            let getBlockTxs = GetBlockTxsMessage(blockHash: compactBlockMessage.header.id, txIndices: missingTxIndices)
            enqueue(.getblocktxn, payload: getBlockTxs.data, to: id)
        }
    }

    func processGetBlockTxs(_ message: BitcoinMessage, from id: PeerID) async throws(Error) {
        guard let _ = state.peers[id] else { preconditionFailure() }
        guard let getBlockTxsMessage = GetBlockTxsMessage(message.payload) else {
            throw .invalidPayload
        }
        guard let block = await blockchain.getBlock(getBlockTxsMessage.blockHash) else {
            throw .blockNotFound
        }
        var txs = [BitcoinTx]()
        for i in getBlockTxsMessage.txIndices {
            txs.append(block.txs[i])
        }
        let blockTxs = BlockTxsMessage(blockHash: block.id, txs: txs)
        enqueue(.blocktxn, payload: blockTxs.data, to: id)
    }

    func processBlockTxs(_ message: BitcoinMessage, from id: PeerID) async throws(Error) {
        guard let peer = state.peers[id] else { preconditionFailure() }

        guard let blockTxsMessage = BlockTxsMessage(message.payload) else {
            throw .invalidPayload
        }

        guard var pendingBlockTxs = peer.pendingBlockTxs else { return }
        state.peers[id]?.pendingBlockTxs = .none

        var j = 0
        for i in pendingBlockTxs.indices {
            if pendingBlockTxs[i] == .none {
                pendingBlockTxs[i] = blockTxsMessage.txs[j]
                j += 1
            }
        }

        guard var block = await blockchain.getHeader(blockTxsMessage.blockHash) else {
            throw .blockNotFound
        }
        block.txs = pendingBlockTxs.compactMap { $0 }
        do {
            try await blockchain.processBlock(block)
        } catch {
            throw .invalidBlock
        }
    }

    static let minCompactBlocksVersion = 2
    static let maxCompactBlocksVersion = 2
}
