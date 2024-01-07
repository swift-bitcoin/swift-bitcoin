import ServiceLifecycle
import NIOCore
import NIOPosix
import JSONRPC
import BitcoinP2P

actor RPCService: Service {

    struct Status {
        var isRunning = false
        var isListening = false
        var port = Int?.none
        var overallTotalConnections = 0
    }

    init(port: Int, eventLoopGroup: EventLoopGroup, p2pService: P2PService, p2pClientService0: P2PClientService) {
        self.port = port
        self.eventLoopGroup = eventLoopGroup
        self.p2pService = p2pService
        self.p2pClientService0 = p2pClientService0
    }

    let port: Int // Configuration
    private(set) var status = Status()
    private let eventLoopGroup: EventLoopGroup
    private let p2pService: P2PService
    private let p2pClientService0: P2PClientService
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
                let p2pStatus = await p2pService.status
                let p2pClientStatus = await p2pClientService0.status
                try await outbound.write(.init(id: request.id, result: .string("""
                    RPC server status:
                    \(status)

                    P2P server status:
                    \(p2pStatus)

                    P2P client 0 status:
                    \(p2pClientStatus)
                """) as JSONObject))
            case "stop":
                try await outbound.write(.init(id: request.id, result: .string("Stopping…") as JSONObject))
                await serviceGroup?.triggerGracefulShutdown()
            case "start-p2p":
                if case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .integer(port) = first {
                    try await outbound.write(.init(id: request.id, result: .string("Staring P2P server on port \(port)…") as JSONObject))
                    await p2pService.start(port: port)
                } else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("Port (integer) is required."))))
                }
            case "stop-p2p":
                try await outbound.write(.init(id: request.id, result: .string("Stopping P2P server…") as JSONObject))
                await p2pService.stop()
            case "connect":
                if case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .integer(port) = first {
                    try await outbound.write(.init(id: request.id, result: .string("Connecting to peer @\(port)…") as JSONObject))
                    await p2pClientService0.connect(port)
                } else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("Port (integer) is required."))))
                }
            case "disconnect":
                if case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .integer(port) = first {
                    try await outbound.write(.init(id: request.id, result: .string("Disconnecting from peer @\(port)…") as RPCObject))
                    await p2pClientService0.disconnect()
                } else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("Port (integer) is required."))))
                }
            default: break
            }
        }
    }
}
