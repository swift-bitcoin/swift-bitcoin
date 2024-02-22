import Bitcoin
import BitcoinP2P
import AsyncAlgorithms
import ServiceLifecycle
import NIO

public actor P2PService: Service {

    public struct Status {
        public var isRunning = false
        public var isListening = false
        public var port = Int?.none
        public var overallTotalConnections = 0
        public var connectionsThisSession = 0
        public var activeConnections = 0
    }

    public init(eventLoopGroup: EventLoopGroup, bitcoinService: BitcoinService) {
        self.eventLoopGroup = eventLoopGroup
        self.bitcoinService = bitcoinService
    }

    private let eventLoopGroup: EventLoopGroup
    private let bitcoinService: BitcoinService
    private(set) public var status = Status() // Network status

    private var listenRequests = AsyncChannel<()>() // We'll send () to this channel whenever we want the service to bootstrap itself

    private var serverChannel: NIOAsyncChannel<NIOAsyncChannel<BitcoinMessage, BitcoinMessage>, Never>?
    private var peers = [BitcoinPeer]()

    public func run() async throws {
        // Update status
        status.isRunning = true

        try await withGracefulShutdownHandler {
            for await _ in listenRequests.cancelOnGracefulShutdown() {
                try await startListening()
            }
        } onGracefulShutdown: {
            print("P2P server shutting down gracefully…")
        }
    }

    public func start(port: Int) async {
        guard serverChannel == nil else { return }
        status.port = port
        await listenRequests.send(()) // Signal to start listening
    }

    public func stopListening() async throws {
        try await serverChannel?.channel.close()
        serverChannel = .none
        status.isListening = false
        status.port = .none
    }

    public func pingAll() async throws {
        for peer in peers {
            try await peer.sendPing()
        }
    }

    private func registerPeer(_ peer: BitcoinPeer) -> Int {
        peers.append(peer)
        return peers.count - 1
    }

    private func deregisterPeer(_ index: Int) {
        peers.remove(at: index)
        status.activeConnections -= 1
    }

    private func startListening() async throws {
        guard let port = status.port else { return }

        // Bootstraping server channel.
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
        let serverChannel = try await bootstrap.bind(
            host: "127.0.0.1",
            port: port
        ) { channel in
            // This closure is called for every inbound connection.
            channel.pipeline.addHandlers([
                ByteToMessageHandler(MessageCoder()),
                MessageToByteHandler(MessageCoder())
            ]).eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<BitcoinMessage, BitcoinMessage>(wrappingChannelSynchronously: channel)
            }
        }
        self.serverChannel = serverChannel

        // Accept connections
        try await withThrowingDiscardingTaskGroup { group in
            try await serverChannel.executeThenClose { serverChannelInbound in
                print("P2P server accepting incoming connections on port \(port)…")
                status.isListening = true
                status.port = port
                status.connectionsThisSession = 0
                status.activeConnections = 0

                for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                    print("P2P server received incoming connection from peer @ \(connectionChannel.channel.remoteAddress?.port ?? -1).")
                    status.overallTotalConnections += 1
                    status.connectionsThisSession += 1
                    status.activeConnections += 1

                    let remotePort = connectionChannel.channel.remoteAddress?.port ?? -1
                    let peer = BitcoinPeer(bitcoinService: self.bitcoinService, isClient: false)
                    let peerID = registerPeer(peer)

                    group.addTask {
                        do {
                            try await connectionChannel.executeThenClose { inbound, outbound in
                                try await withThrowingDiscardingTaskGroup { group in
                                    group.addTask {
                                        try await peer.start()
                                    }
                                    group.addTask {
                                        for await message in await peer.messagesOut.cancelOnGracefulShutdown() {
                                            try await outbound.write(message)
                                        }
                                    }
                                    group.addTask {
                                        for try await message in inbound.cancelOnGracefulShutdown() {
                                            await peer.messagesIn.send(message)
                                        }
                                        // Disconnected
                                        print("P2P server disconnected from peer @ \(remotePort).")
                                        try await peer.stop()
                                    }
                                }
                            }
                        } catch {
                            // TODO: Handle errors
                            print("Unexpected error:\n\(error.localizedDescription)")
                        }
                        await self.deregisterPeer(peerID)
                    }
                }
            }
        }
    }
}
