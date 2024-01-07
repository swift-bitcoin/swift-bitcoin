import ServiceLifecycle
import NIOCore
import NIOPosix

public actor P2PService: Service {

    public struct Status {
        var isRunning = false
        var isListening = false
        var port = Int?.none
        var overallTotalConnections = 0
        var connectionsThisSession = 0
        var activeConnections = 0
    }

    private enum ControlAction {
        case start(Int), stop
    }

    public init(eventLoopGroup: EventLoopGroup) {
        self.eventLoopGroup = eventLoopGroup
    }

    private(set) public var status = Status()
    private let eventLoopGroup: EventLoopGroup
    private var serverChannel: NIOAsyncChannel<NIOAsyncChannel<Message, Message>, Never>?
    private var controlActionHandler: ((ControlAction) -> ())?

    private var controlActions: AsyncStream<ControlAction> {
        AsyncStream { continuation in
            controlActionHandler = { action in
                continuation.yield(action)
            }
        }
    }

    public func run() async throws {

        // Update status
        status.isRunning = true

        try await withGracefulShutdownHandler {

            for await action in controlActions.cancelOnGracefulShutdown() {
                switch action {
                case .start(let port):
                    guard serverChannel == nil else { break }
                    Task {
                        try await startListening(port: port)
                    }
                case .stop:
                    try await stopListening()
                }
            }
            print("P2P server: no more control actions.")
        } onGracefulShutdown: {
            // status.isRunning = false
            print("P2P server shutting down gracefully…")
        }
    }

    public func start(port: Int) {
        controlActionHandler?(.start(port))
    }

    public func stop() {
        controlActionHandler?(.stop)
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
                            try await connectionChannel.executeThenClose { [weak self] in
                                try await handleIO($0, $1)
                                print("P2P server disconnected from peer @ \(connectionChannel.channel.remoteAddress?.port ?? -1).")

                                await self?.decreaseActiveConnections()
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

    private func stopListening() async throws {
        try await serverChannel?.channel.close()
        serverChannel = .none
        status.isListening = false
        status.port = .none
    }
}
