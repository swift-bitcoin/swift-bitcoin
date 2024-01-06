import ServiceLifecycle
import NIOCore
import NIOPosix
import JSONRPC

actor RPCService: Service {

    struct Status {
        var isRunning = false
        var isListening = false
        var port = Int?.none
        var overallTotalConnections = 0
    }

    init(port: Int, eventLoopGroup: EventLoopGroup) {
        self.port = port
        self.eventLoopGroup = eventLoopGroup
    }

    let port: Int // Configuration
    private(set) var status = Status()
    private let eventLoopGroup: EventLoopGroup
    private var serviceGroup: ServiceGroup?

    func setServiceGroup(_ serviceGroup: ServiceGroup) {
        self.serviceGroup = serviceGroup
    }

    func run() async throws {

        // Bootstraping server channel.
        let serverChannel = try await ServerBootstrap(
            group: eventLoopGroup
        )
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .bind(
            host: "127.0.0.1",
            port: port
        ) { channel in

            // This closure is called for every inbound connection.
            channel.pipeline.addHandlers([
                IdleStateHandler(readTimeout: TimeAmount.seconds(5)),
                HalfCloseOnTimeout(),
                ByteToMessageHandler(NewlineEncoder()),
                MessageToByteHandler(NewlineEncoder()),
                CodableCodec<JSONRequest, JSONResponse>()
            ]).eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<JSONRequest, JSONResponse>(wrappingChannelSynchronously: channel)
            }
        }

        // Update status
        status.isRunning = true

        try await withGracefulShutdownHandler {
            try await withThrowingDiscardingTaskGroup { group in
                try await serverChannel.executeThenClose { serverChannelInbound in

                    print("RPC server accepting incoming connections on port \(port)…")
                    status.isListening = true
                    status.port = port

                    for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                        print("Incoming RPC connection from client @ \(connectionChannel.channel.remoteAddress?.port ?? -1)")
                        status.overallTotalConnections += 1

                        group.addTask {
                            do {
                                try await connectionChannel.executeThenClose {
                                    try await self.handleRPC($0, $1)

                                    print("RPC server disconnected from client @ \(connectionChannel.channel.remoteAddress?.port ?? -1).")

                                }
                            } catch {
                                // TODO: Handle errors
                                print("An unexpected error has occurred:\n\n\(error.localizedDescription)")
                            }
                        }
                    }
                    print("No more incoming RPC connections.")
                }
                print("RPC server stoped (no longer listening for connections).")
            }

        } onGracefulShutdown: {
            print("RPC server shutting down gracefully…")
        }

    }

    private func handleRPC(_ inbound: NIOAsyncChannelInboundStream<JSONRequest>, _ outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws -> () {

        for try await request in inbound.cancelOnGracefulShutdown() {
            switch request.method {
            case "status":
                try await outbound.write(.init(id: request.id, result: .string("""
                    RPC server status:
                    \(status)
                """) as JSONObject))
            case "stop":
                try await outbound.write(.init(id: request.id, result: .string("Stopping…") as JSONObject))
                await serviceGroup?.triggerGracefulShutdown()
            default: break
            }
        }
    }
}
