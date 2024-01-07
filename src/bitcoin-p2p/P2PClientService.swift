import ServiceLifecycle
import NIOCore
import NIOPosix

public actor P2PClientService: Service {

    public struct Status {
        var isRunning = false
        var isConnected = false
        var port = Int?.none
        var overallTotalConnections = 0
    }

    private enum ControlAction {
        case connect(Int), disconnect
    }

    public init(eventLoopGroup: EventLoopGroup) {
        self.eventLoopGroup = eventLoopGroup
    }

    private(set) public var status = Status()
    private let eventLoopGroup: EventLoopGroup
    private var clientChannel: NIOAsyncChannel<Message, Message>?
    private var controlActionHandler: ((ControlAction) -> ())?

    public func run() async throws {
        try await withGracefulShutdownHandler {

            status.isRunning = true

            for await action in controlActions.cancelOnGracefulShutdown() {
                switch action {
                case .connect(let port):
                    guard clientChannel == nil else { break }
                    Task {
                        try await connectToPeer(on: port)
                    }
                case .disconnect:
                    try await disconnectFromPeer()
                }
            }
            print("P2P client: No longer receiving control actions.")
        } onGracefulShutdown: {
            print("P2P client shutting down gracefully…")
        }
    }

    public func connect(_ port: Int) {
        controlActionHandler?(.connect(port))
    }

    public func disconnect() {
        controlActionHandler?(.disconnect)
    }

    private var controlActions: AsyncStream<ControlAction> {
        AsyncStream { continuation in
            controlActionHandler = { action in
                continuation.yield(action)
            }
        }
    }

    private func connectToPeer(on port: Int) async throws {

        let clientChannel = try await ClientBootstrap(
            group: eventLoopGroup
        ).connect(
            host: "127.0.0.1",
            port: port
        ) { channel in
            channel.pipeline.addHandlers([
                MessageToByteHandler(MessageCoder()),
                ByteToMessageHandler(MessageCoder())
            ]).eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<Message, Message>(wrappingChannelSynchronously: channel)
            }
        }
        self.clientChannel = clientChannel

        try await clientChannel.executeThenClose {
            print("P2P client ready to connect to peer @\(port)…")
            status.isConnected = true
            status.port = port
            status.overallTotalConnections += 1

            try await handleIO(isClient: true, $0, $1)

            print("P2P client got disconnected from peer @\(port).")
            status.isConnected = false
        }
    }

    private func disconnectFromPeer() async throws {
        print("P2P client disconnecting from remote peer @\(status.port ?? -1)…")
        try await clientChannel?.channel.close()
        clientChannel = .none
        status.isConnected = false
        status.port = .none
    }
}
