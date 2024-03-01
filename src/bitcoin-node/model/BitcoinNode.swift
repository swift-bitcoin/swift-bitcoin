import Foundation
import Bitcoin
import AsyncAlgorithms

actor BitcoinNode {

    enum Error: Swift.Error {
        case connectionToSelf, unsupportedVersion, unsupportedServices, invalidPayload, pingPongMismatch
    }

    struct Peer {
        let address: IPv6Address
        let port: Int
        let incoming: Bool

        // Information from the version message sent by the peer
        var preferredVersion = ProtocolVersion?.none
        var userAgent = String?.none
        var addressDeclared = IPv6Address?.none
        var portDeclared = Int?.none
        var services = ProtocolServices?.none
        var relay = Bool?.none
        var nonce = UInt64?.none

        /// Difference between the time reported by the peer and our time at the time we receive the version message.
        var timeDiff = 0

        // Status
        var handshakeComplete = false
        var height = 0
        var lastPingNonce = UInt64?.none

        var outgoing: Bool { !incoming }
    }

    init(bitcoinService: BitcoinService, network: NodeNetwork = .regtest) {
        self.bitcoinService = bitcoinService
        self.network = network
    }

    let bitcoinService: BitcoinService
    let network: NodeNetwork

    /// Subscription to the bitcoin service's blocks channel.
    var blocks = AsyncChannel<TransactionBlock>?.none

    /// IP address as string.
    var address = IPv6Address?.none

    /// Our port might not exist if peer-to-peer server is down. We can still be conecting with peers as a client.
    var port = Int?.none

    /// Peer information.
    var peers = [UUID : Peer]()

    /// Channel for delivering message to peers.
    var peerOuts = [UUID : AsyncChannel<BitcoinMessage>]()

    /// The node's randomly generated identifier (nonce). This is sent with `version` messages.
    let nonce = UInt64.random(in: UInt64.min ... UInt64.max)

    /// Called when the peer-to-peer service stops listening for incoming connections.
    func resetAddress() {
        address = .none
        port = .none
    }

    /// Receive address information from the peer-to-peer service whenever it's actively listening.
    func setAddress(_ host: String, _ port: Int) {
        self.address = IPv6Address.fromHost(host)
        self.port = port
    }

    /// We unsubscribe from Bitcoin service's blocks.
    func stop() async throws {
        if let blocks {
            await bitcoinService.unsubscribe(blocks)
        }
    }

    /// Send a ping to each of our peers. Calling this function will create child tasks.
    func pingAll() async {
        await withDiscardingTaskGroup {
            for peerID in peers.keys {
                $0.addTask {
                    await self.sendPingTo(peerID)
                }
            }
        }
    }

    /// Registers a peer with the node. Incoming means we are the listener. Otherwise we are the node initiating the connection.
    func addPeer(host: String, port: Int, incoming: Bool = true) async -> UUID {
        let id = UUID()
        peers[id] = Peer(address: IPv6Address.fromHost(host), port: port, incoming: incoming)
        peerOuts[id] = .init()
        await connect(id)
        return id
    }

    /// Deregisters a peer and cleans up outbound channels.
    func removePeer(_ id: UUID) {
        peerOuts[id]?.finish()
        peerOuts.removeValue(forKey: id)
        peers.removeValue(forKey: id)
    }

    /// Returns a channel for a given peer's outbox. The caller can be notified of new messages generated for this peer.
    func getChannel(for peerID: UUID) -> AsyncChannel<BitcoinMessage> {
        precondition(peers[peerID] != nil)
        return peerOuts[peerID]!
    }

    func makeVersion(for peerID: UUID) async -> VersionMessage {
        guard let peer = peers[peerID] else { preconditionFailure() }

        let lastBlock = await bitcoinService.blockchain.count - 1
        return .init(
            protocolVersion: Self.version,
            services: Self.services,
            receiverServices: peer.services ?? .empty,
            receiverAddress: peer.addressDeclared ?? .unspecified,
            receiverPort: peer.portDeclared ?? 0,
            transmitterServices: Self.services,
            transmitterAddress: address ?? .unspecified,
            transmitterPort: port ?? 0,
            nonce: nonce,
            userAgent: Self.userAgent,
            startHeight: lastBlock,
            relay: true)
    }

    /// Starts the handshake process but only if its an outgoing peer – i.e. we initiated the connection. Generates a child task for delivering the initial version message.
    func connect(_ peerID: UUID) async {
        guard let peer = peers[peerID], peer.outgoing else { return }

        // Outbound connection sequence:
        // -> version (we send the first message)
        // -> wtxidrelay
        // -> sendaddrv2
        // <- version
        // -> verack
        // -> getaddr
        // <- verack
        // -> sendcmpct
        // -> ping
        // -> getheaders
        // -> feefilter
        // <- pong

        let versionMessage = await makeVersion(for: peerID)
        print("Our version:")
        debugPrint(versionMessage)

        let message = BitcoinMessage(network: network, command: .version, payload: versionMessage.data)
        Task {
            await peerOuts[peerID]?.send(message)
        }
    }

    /// Sends a ping message to a peer. Creates a new child task.
    func sendPingTo(_ peerID: UUID) async {
        let ping = PingMessage()
        peers[peerID]?.lastPingNonce = ping.nonce
        let pingMessage = BitcoinMessage(network: .regtest, command: .ping, payload: ping.data)
        Task {
            await peerOuts[peerID]?.send(pingMessage)
        }
    }

    /// Process an incoming message from a peer. This will sometimes result in sending out one or more messages back to the peer. The function will ultimately create a child task per message sent.
    func processMessage(_ message: BitcoinMessage, from peerID: UUID) async throws {
        print("\n<<<")
        debugPrint(message)
        let response = switch message.command {
        case .version:
            try await processVersion(message, from: peerID)
        case .verack:
            processVerack(message, from: peerID)
        case .ping:
            try processPing(message, from: peerID)
        case .pong:
            try processPong(message, from: peerID)
        case .wtxidrelay, .sendaddrv2, .sendcmpct, .getheaders, .feefilter, .getaddr, .unknown:
            BitcoinMessage?.none
        }
        if let response {
            debugPrint(response)
            Task {
                await peerOuts[peerID]?.send(response)
            }
        } else {
            print("No response sent.")
        }
        print(">>>\n")
    }

    /// Processes an incoming version message as part of the handshake.
    private func processVersion(_ message: BitcoinMessage, from peerID: UUID) async throws -> BitcoinMessage? {

        // Inbound connection sequence:
        // <- version (we receive the first message from the connecting peer)
        // -> version
        // -> wtxidrelay
        // -> sendaddrv2
        // -> wtxidrelay
        // -> sendaddrv2
        // <- verack
        // -> verack
        // -> sendcmpct
        // -> ping
        // -> getheaders
        // -> feefilter
        // <- pong

        guard let peer = peers[peerID] else { return .none }

        let ourTime = Date.now

        guard let peerVersion = VersionMessage(message.payload) else {
            preconditionFailure()
        }

        print("Peer version:")
        debugPrint(peerVersion)

        if peerVersion.nonce == nonce {
            print("Error: Connection to self.")
            throw Error.connectionToSelf
        }
        if peerVersion.services.intersection(Self.services) != Self.services {
            throw Error.unsupportedServices
        }

        // Inbound connection. Version message is the first message.
        if peerVersion.protocolVersion < Self.version {
            throw Error.unsupportedVersion
        }

        peers[peerID]?.nonce = peerVersion.nonce
        peers[peerID]?.preferredVersion = peerVersion.protocolVersion
        peers[peerID]?.userAgent = peerVersion.userAgent
        peers[peerID]?.services = peerVersion.services
        peers[peerID]?.addressDeclared = peerVersion.transmitterAddress
        peers[peerID]?.portDeclared = peerVersion.transmitterPort
        peers[peerID]?.relay = peerVersion.relay
        peers[peerID]?.timeDiff = Int(ourTime.timeIntervalSince1970) - Int(peerVersion.timestamp.timeIntervalSince1970)
        peers[peerID]?.height = peerVersion.startHeight

        if peer.outgoing {
            // Outbound connection. Version message is a response to our version.
            if peerVersion.protocolVersion > Self.version {
                throw Error.unsupportedVersion
            }
            return .init(network: .regtest, command: .verack, payload: Data())
        }

        let versionMessage = await makeVersion(for: peerID)

        print("Our version:")
        debugPrint(versionMessage)

        return BitcoinMessage(network: .regtest, command: .version, payload: versionMessage.data)
    }

    private func processVerack(_ message: BitcoinMessage, from peerID: UUID) -> BitcoinMessage? {
        guard let peer = peers[peerID] else { return .none }

        peers[peerID]?.handshakeComplete = true

        print("Handshake successful.")
        debugPrint(peers[peerID]!)

        return peer.outgoing ? .none : .init(network: .regtest, command: .verack, payload: .init())
    }

    private func processPing(_ message: BitcoinMessage, from peerID: UUID) throws -> BitcoinMessage? {
        guard let ping = PingMessage(message.payload) else {
            throw Error.invalidPayload
        }
        debugPrint(ping)
        let pong = PongMessage(nonce: ping.nonce)
        debugPrint(pong)
        return .init(network: .regtest, command: .pong, payload: pong.data)
    }

    private func processPong(_ message: BitcoinMessage, from peerID: UUID) throws -> BitcoinMessage? {
        guard let pong = PongMessage(message.payload) else {
            throw Error.invalidPayload
        }
        debugPrint(pong)
        guard let nonce = peers[peerID]?.lastPingNonce, pong.nonce == nonce else {
            throw Error.pingPongMismatch
        }
        peers[peerID]?.lastPingNonce = .none
        return .none
    }

    static let version = ProtocolVersion.latest
    static let userAgent = "/SwiftBitcoin:0.1.0/"
    static let services = ProtocolServices.all
}
