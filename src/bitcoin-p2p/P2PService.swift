import Bitcoin
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

    private var serverChannel: NIOAsyncChannel<NIOAsyncChannel<Message, Message>, Never>?

    public func run() async throws {

        // Update status
        status.isRunning = true

        await withGracefulShutdownHandler {

            // We want to keep the service alive while we connect/disconnect from servers. Unless there is a shutdown signal.
            for await _ in AsyncChannel<()>().cancelOnGracefulShutdown() { }

        } onGracefulShutdown: {
            // status.isRunning = false
            print("P2P server shutting down gracefully…")
        }
    }

    public func start(port: Int) {
        guard serverChannel == nil else { return }
        Task {
            try await startListening(port: port)
        }
    }

    public func stopListening() async throws {
        try await serverChannel?.channel.close()
        serverChannel = .none
        status.isListening = false
        status.port = .none
    }

    private func decreaseActiveConnections() {
        status.activeConnections -= 1
    }

    private func startListening(port: Int) async throws {

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
                try NIOAsyncChannel<Message, Message>(wrappingChannelSynchronously: channel)
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

                    group.addTask {
                        do {
                            try await connectionChannel.executeThenClose { [self] in
                                try await handleIO(bitcoinService: self.bitcoinService, $0, $1)
                                print("P2P server disconnected from peer @ \(connectionChannel.channel.remoteAddress?.port ?? -1).")

                                await self.decreaseActiveConnections()
                            }
                        } catch {
                            // TODO: Handle errors
                            print("An unexpected error has occurred:\n\n\(error.localizedDescription)")
                        }
                    }
                }
                print("P2P server: No more incoming connections.")
            }
            print("P2P server stopped listening.")
        }
    }
}
