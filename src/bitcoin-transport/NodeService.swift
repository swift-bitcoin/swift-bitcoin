import Foundation
import AsyncAlgorithms
import BitcoinBase
import BitcoinBlockchain

/// Manages connection with peers, process incoming messages and sends responses.
public actor NodeService: Sendable {

    ///  Creates an instance of a bitcoin node service.
    /// - Parameters:
    ///   - bitcoinService: The bitcoin service actor instance backing this node.
    ///   - network: The type of bitcoin network this node is part of.
    ///   - version: Protocol version number.
    ///   - services: Supported services.
    ///   - feeFilterRate: An arbitrary fee rate by which to filter transactions.
    public init(bitcoinService: BitcoinService, network: NodeNetwork = .regtest, version: ProtocolVersion = .latest, services: ProtocolServices = .all, feeFilterRate: BitcoinAmount? = .none) {
        self.bitcoinService = bitcoinService
        self.network = network
        self.version = version
        self.services = services
        if let feeFilterRate {
            self.feeFilterRate = feeFilterRate
        }
    }

    /// The bitcoin service actor instance backing this node.
    public let bitcoinService: BitcoinService

    /// The type of bitcoin network this node is part of.
    public let network: NodeNetwork

    public let version: ProtocolVersion
    public let services: ProtocolServices

    /// Subscription to the bitcoin service's blocks channel.
    public var blocks = AsyncChannel<TransactionBlock>?.none

    /// IP address as string.
    var address = IPv6Address?.none

    /// Our port might not exist if peer-to-peer server is down. We can still be conecting with peers as a client.
    var port = Int?.none

    /// BIP133: Our current fee filter rate for transactions relayed to us by peers. Default: 1 satoshi per virtual byte (sat/vbyte).
    var feeFilterRate = BitcoinAmount(1) // TODO: Allow to be changed via RPC command, #189

    /// Peer information.
    var peers = [UUID : Peer]()

    /// Channel for delivering message to peers.
    var peerOuts = [UUID : AsyncChannel<BitcoinMessage>]()

    /// The node's randomly generated identifier (nonce). This is sent with `version` messages.
    let nonce = UInt64.random(in: UInt64.min ... UInt64.max)

    var awaitingHeadersFrom = UUID?.none
    var awaitingHeadersSince = Date?.none

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

    /// We unsubscribe from Bitcoin service's blocks.
    public func stop() async throws {
        if let blocks {
            await bitcoinService.unsubscribe(blocks)
        }
    }

    /// Send a ping to each of our peers. Calling this function will create child tasks.
    public func pingAll() async {
        await withDiscardingTaskGroup {
            for id in peers.keys {
                $0.addTask {
                    await self.sendPingTo(id)
                }
            }
        }
    }

    /// Request headers from peers.
    public func requestHeaders() async {
        let maxHeight = peers.values.reduce(-1) { max($0, $1.height) }
        let ourHeight = await bitcoinService.headers.count - 1
        guard maxHeight > ourHeight,
              let (id, _) = peers.filter({ $0.value.height == maxHeight }).randomElement() else {
            return
        }
        await requestHeaders(id)
    }

    /// Request headers from a specific peer.
    func requestHeaders(_ id: UUID) async {
        guard let _ = peers[id] else { preconditionFailure() }
        let locatorHashes = await bitcoinService.makeBlockLocator()
        let getHeaders = GetHeadersMessage(protocolVersion: .latest, locatorHashes: locatorHashes)
        awaitingHeadersFrom = id
        awaitingHeadersSince = .now
        enqueue(.getheaders, payload: getHeaders.data, to: id)
    }

    func requestNextMissingBlocks(_ id: UUID) async {
        guard let peer = peers[id] else { preconditionFailure() }

        let numberOfBlocksToRequest = Peer.maxInTransitBlocks - peer.inTransitBlocks
        guard numberOfBlocksToRequest > 0 else { return }

        let blockIDs = await bitcoinService.getNextMissingBlocks(numberOfBlocksToRequest)

        guard !blockIDs.isEmpty else { return }

        let getData = GetDataMessage(items:
            blockIDs.map { .init(type: .witnessBlock, hash: $0) }
        )
        peers[id]?.inTransitBlocks += blockIDs.count
        enqueue(.getdata, payload: getData.data, to: id)
    }

    /// Registers a peer with the node. Incoming means we are the listener. Otherwise we are the node initiating the connection.
    public func addPeer(host: String = IPv4Address.empty.description, port: Int = 0, incoming: Bool = true) async -> UUID {
        let id = UUID()
        peers[id] = Peer(address: IPv6Address.fromHost(host), port: port, incoming: incoming)
        peerOuts[id] = .init()
        return id
    }

    /// Deregisters a peer and cleans up outbound channels.
    public func removePeer(_ id: UUID) {
        peerOuts[id]?.finish()
        peerOuts.removeValue(forKey: id)
        peers.removeValue(forKey: id)
    }

    /// Returns a channel for a given peer's outbox. The caller can be notified of new messages generated for this peer.
    public func getChannel(for id: UUID) -> AsyncChannel<BitcoinMessage> {
        precondition(peers[id] != nil)
        return peerOuts[id]!
    }

    func makeVersion(for id: UUID) async -> VersionMessage {
        guard let peer = peers[id] else { preconditionFailure() }

        let lastBlock = await bitcoinService.transactions.count - 1
        return .init(
            protocolVersion: version,
            services: services,
            receiverServices: peer.version?.services,
            receiverAddress: peer.version?.transmitterAddress,
            receiverPort: peer.version?.transmitterPort,
            transmitterAddress: address,
            transmitterPort: port,
            nonce: nonce,
            startHeight: lastBlock)
    }

    /// Starts the handshake process but only if its an outgoing peer – i.e. we initiated the connection. Generates a child task for delivering the initial version message.
    public func connect(_ id: UUID) async {
        guard let peer = peers[id], peer.outgoing else { return }

        let versionMessage = await makeVersion(for: id)

        enqueue(.version, payload: versionMessage.data, to: id)
        enqueue(.wtxidrelay, to: id)
        enqueue(.sendaddrv2, to: id)

        // await send(.version, payload: versionMessage.data, to: id)
        // peers[id]?.versionSent = true
    }

    /// Sends a ping message to a peer. Creates a new child task.
    func sendPingTo(_ id: UUID) async {
        let ping = PingMessage()
        peers[id]?.lastPingNonce = ping.nonce
        await send(.ping, payload: ping.data, to: id)
    }

    /// Enqueues a ping message to a peer. Creates a new child task.
    func enqueuePingTo(_ id: UUID) {
        let ping = PingMessage()
        peers[id]?.lastPingNonce = ping.nonce
        enqueue(.ping, payload: ping.data, to: id)
    }

    public func popMessage(_ id: UUID) -> BitcoinMessage? {
        guard let peer = peers[id] else { preconditionFailure() }
        guard !peer.outbox.isEmpty else { return .none }
        return peers[id]!.outbox.removeFirst()
    }

    /// Process an incoming message from a peer. This will sometimes result in sending out one or more messages back to the peer. The function will ultimately create a child task per message sent.
    public func processMessage(_ message: BitcoinMessage, from id: UUID) async throws {

        guard let peer = peers[id] else { return }

        /// First message must always be `version`.
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
        case .getaddr, .addrv2, .inv, .notfound, .unknown:
            break
        }
    }

    /// Sends a message.
    private func send(_ command: MessageCommand, payload: Data = .init(), to id: UUID) async {
        await peerOuts[id]?.send(.init(command, payload: payload, network: network))
    }

    /// Queues a message.
    private func enqueue(_ command: MessageCommand, payload: Data = .init(), to id: UUID) {
        peers[id]?.outbox.append(.init(command, payload: payload, network: network))
    }

    /// Processes an incoming version message as part of the handshake.
    private func processVersion(_ message: BitcoinMessage, from id: UUID) async throws {

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

        guard let peer = peers[id] else { return }

        let ourTime = Date.now

        guard let peerVersion = VersionMessage(message.payload) else {
            preconditionFailure()
        }

        if peerVersion.nonce == nonce {
            throw Error.connectionToSelf
        }

        if peerVersion.services.intersection(services) != services {
            throw Error.unsupportedServices
        }

        // Inbound connection. Version message is the first message.
        if peerVersion.protocolVersion < version {
            throw Error.unsupportedVersion
        }

        peers[id]?.version = peerVersion
        peers[id]?.timeDiff = Int(ourTime.timeIntervalSince1970) - Int(peerVersion.timestamp.timeIntervalSince1970)
        peers[id]?.height = peerVersion.startHeight

        // Outbound connection. Version message is a response to our version.
        if peer.outgoing && peerVersion.protocolVersion > version {
            throw Error.unsupportedVersion
        }

        if peer.incoming {
            let versionMessage = await makeVersion(for: id)

            // await send(.version, payload: versionMessage.data, to: id)
            enqueue(.version, payload: versionMessage.data, to: id)
            enqueue(.wtxidrelay, to: id)
            enqueue(.sendaddrv2, to: id)

            //peers[id]?.versionSent = true
        }

        // BIP339
        // await send(.wtxidrelay, to: id)
        // peers[id]?.witnessRelayPreferenceSent = true

        // BIP155
        // await send(.sendaddrv2, to: id)
        // peers[id]?.v2AddressPreferenceSent = true

        // await send(.verack, to: id)
        // peers[id]?.versionAckSent = true
    }

    /// BIP339
    private func processWTXIDRelay(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = peers[id] else { return }

        // Disconnect peers that send a WTXIDRELAY message after VERACK.
        if peer.versionAckReceived {
            // Because we disconnect nodes that don't signal for WTXID relay, this code will never be reached.
            throw Error.requestedWTXIDRelayAfterVerack
        }

        peers[id]?.witnessRelayPreferenceReceived = true

        if peer.v2AddressPreferenceReceived {
            enqueue(.verack, to: id)
        }
    }

    /// BIP155
    private func processSendAddrV2(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = peers[id] else { return }

        // Disconnect peers that send a SENDADDRV2 message after VERACK.
        if peer.versionAckReceived {
            // Because we disconnect nodes that don't ask for v2, this code will never be reached.
            throw Error.requestedV2AddrAfterVerack
        }

        peers[id]?.v2AddressPreferenceReceived = true

        if peer.witnessRelayPreferenceReceived {
            enqueue(.verack, to: id)
        }
    }

    private func processVerack(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = peers[id] else { return }

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

        peers[id]?.versionAckReceived = true

        if peers[id]!.handshakeComplete {
            print("Handshake successful.")
        }

        // BIP152 send a burst of supported compact block versions followed by a ping to lock it down.
        enqueue(.sendcmpct, payload: SendCompactMessage().data, to: id)
        peers[id]?.compactBlocksPreferenceSent = true
        if let pong = peer.pongOnHoldUntilCompactBlocksPreference {
            enqueue(.pong, payload: pong.data, to: id)
            peers[id]?.pongOnHoldUntilCompactBlocksPreference = .none
        }
        enqueuePingTo(id)
        await requestHeaders(id)
        enqueue(.feefilter, payload: FeeFilterMessage(feeRate: feeFilterRate).data, to: id)
    }

    private func processPing(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = peers[id] else { return }

        guard let ping = PingMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let pong = PongMessage(nonce: ping.nonce)

        // BIP152 We need to hold the pong until the compact block version was sent.
        if peer.compactBlocksPreferenceSent {
            enqueue(.pong, payload: pong.data, to: id)
        } else {
            peers[id]?.pongOnHoldUntilCompactBlocksPreference = pong
        }
    }

    private func processPong(_ message: BitcoinMessage, from id: UUID) throws {

        guard let peer = peers[id] else { return }

        guard let pong = PongMessage(message.payload) else {
            throw Error.invalidPayload
        }

        guard let nonce = peers[id]?.lastPingNonce, pong.nonce == nonce else {
            throw Error.pingPongMismatch
        }
        peers[id]?.lastPingNonce = .none

        // BIP152: Lock compact block version on first pong.

        if peer.compactBlocksVersionLocked { return }

        guard let compactBlocksVersion = peer.compactBlocksVersion, compactBlocksVersion >= Self.minCompactBlocksVersion else {
            throw Error.unsupportedCompactBlocksVersion
        }
        peers[id]?.compactBlocksVersionLocked = true
    }

    /// BIP152
    private func processSendCompact(_ message: BitcoinMessage, from id: UUID) throws {
        guard let peer = peers[id] else { return }

        guard let sendCompact = SendCompactMessage(message.payload) else {
            throw Error.invalidPayload
        }

        // We let the negotiation play out for versions lower than our max supported. When version is finally locked we will enforce our minimum supported version as well.
        if peer.compactBlocksVersion == .none, sendCompact.version <= Self.maxCompactBlocksVersion {
            peers[id]?.highBandwidthCompactBlocks = sendCompact.highBandwidth
            peers[id]?.compactBlocksVersion = sendCompact.version
        }
    }

    /// BIP133
    private func processFeeFilter(_ message: BitcoinMessage, from id: UUID) throws {
        guard let feeFilter = FeeFilterMessage(message.payload) else {
            throw Error.invalidPayload
        }

        peers[id]?.feeFilterRate = feeFilter.feeRate
    }

    private func processGetHeaders(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = peers[id] else { return }

        guard let getHeaders = GetHeadersMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let headers = await bitcoinService.findHeaders(using: getHeaders.locatorHashes)
        let headersMessage = HeadersMessage(items: headers)

        enqueue(.headers, payload: headersMessage.data, to: id)
    }

    private func processHeaders(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = peers[id], let awaitingHeadersFrom, let awaitingHeadersSince, awaitingHeadersFrom == id else { return }

        self.awaitingHeadersFrom = .none
        self.awaitingHeadersSince = .none

        if awaitingHeadersSince.timeIntervalSinceNow < -60 {
            return
        }

        guard let headersMessage = HeadersMessage(message.payload) else {
            throw Error.invalidPayload
        }
        do {
            try await bitcoinService.processHeaders(headersMessage.items)
        } catch is BitcoinService.Error {
            peers[id]?.height = await bitcoinService.headers.count - 1
        }

        if headersMessage.moreItems {
            await requestHeaders(id)
        }

        await requestNextMissingBlocks(id)
    }

    func processBlock(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = peers[id] else { preconditionFailure() }

        guard let blockMessage = BlockMessage(message.payload) else {
            throw Error.invalidPayload
        }

        await bitcoinService.processBlock(header: blockMessage.header, transactions: blockMessage.transactions)

        peers[id]?.inTransitBlocks -= 1

        await requestNextMissingBlocks(id)
    }

    func processGetData(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = peers[id] else { preconditionFailure() }

        guard let getDataMessage = GetDataMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let hashes = getDataMessage.items.filter { $0.type == .witnessBlock }.map { $0.hash }
        let blocks = await bitcoinService.getBlocks(hashes)

        for (header, transactions) in blocks {
            let blockMessage = BlockMessage(header: header, transactions: transactions)
            enqueue(.block, payload: blockMessage.data, to: id)
        }
    }

    static let minCompactBlocksVersion = 2
    static let maxCompactBlocksVersion = 2
}
