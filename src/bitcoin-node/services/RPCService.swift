import BitcoinTransport
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain
import BitcoinRPC
import ServiceLifecycle
import NIO
import Logging
import Foundation

private let logger = Logger(label: "swift-bitcoin.rpc")

actor RPCService: Service {

    struct Status {
        var isRunning = false
        var isListening = false
        var host = String?.none
        var port = Int?.none
        var overallTotalConnections = 0
    }

    init(host: String, port: Int, eventLoopGroup: EventLoopGroup, bitcoinNode: NodeService, bitcoinService: BitcoinService, p2pService: P2PService, p2pClientServices: [P2PClientService]) {
        self.host = host
        self.port = port
        self.eventLoopGroup = eventLoopGroup
        self.bitcoinNode = bitcoinNode
        self.bitcoinService = bitcoinService
        self.p2pService = p2pService
        self.p2pClientServices = p2pClientServices
    }

    let host: String
    let port: Int
    private let eventLoopGroup: EventLoopGroup
    private let bitcoinNode: NodeService
    private let bitcoinService: BitcoinService
    private let p2pService: P2PService
    private let p2pClientServices: [P2PClientService]

    private(set) var status = Status() // Network status
    private var serviceGroup: ServiceGroup?

    func setServiceGroup(_ serviceGroup: ServiceGroup) {
        self.serviceGroup = serviceGroup
    }

    func serviceUp() {
        status.isListening = true
        status.host = host
        status.port = port
    }

    func connectionMade() {
        status.overallTotalConnections += 1
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
            host: host,
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

        try await withGracefulShutdownHandler { @Sendable in
            try await withThrowingDiscardingTaskGroup { /* @Sendable */ group in
                try await serverChannel.executeThenClose { /* @Sendable */ serverChannelInbound in

                    logger.info("RPC server accepting incoming connections on port \(host):\(port)…")
                    await serviceUp()

                    for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                        logger.info("Incoming RPC connection from client @ \(String(describing: connectionChannel.channel.remoteAddress))")
                        await connectionMade()

                        group.addTask {
                            do {
                                try await connectionChannel.executeThenClose {
                                    try await self.handleRPC($0, $1)

                                    logger.info("RPC server disconnected from client @ \(String(describing: connectionChannel.channel.remoteAddress)).")

                                }
                            } catch {
                                logger.error("An unexpected error has occurred:\n\(error)")
                            }
                        }
                    }
                    logger.info("No more incoming RPC connections.")
                }
                logger.info("RPC server stopped (no longer listening for connections).")
            }

        } onGracefulShutdown: {
            logger.info("RPC server shutting down gracefully…")
        }

    }

    private func handleRPC(_ inbound: NIOAsyncChannelInboundStream<JSONRequest>, _ outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws -> () {

        for try await request in inbound.cancelOnGracefulShutdown() {
            switch request.method {
            case "status":
                let p2pStatus = await p2pService.status
                // Gathering all clients' statuses
                var p2pClientStatus = ""
                for service in p2pClientServices {
                    p2pClientStatus += "\(await service.status)\n"
                }
                try await outbound.write(.init(id: request.id, result: .string("""
                RPC server status:
                \(status)

                P2P server status:
                \(p2pStatus)

                P2P clients' status:
                \(p2pClientStatus)
                """) as JSONObject))
            case "stop":
                try await outbound.write(.init(id: request.id, result: .string("Stopping…") as JSONObject))
                await serviceGroup?.triggerGracefulShutdown()
            case "start-p2p":
                if case let .list(objects) = RPCObject(request.params),
                   objects.count > 1,
                   case let .string(host) = objects[0],
                   case let .integer(port) = objects[1] {
                    try await outbound.write(.init(id: request.id, result: .string("Staring P2P server on \(host):\(port)…") as JSONObject))
                    await p2pService.start(host: host, port: port)
                } else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("Port (integer) is required."))))
                }
            case "stop-p2p":
                try await outbound.write(.init(id: request.id, result: .string("Stopping P2P server…") as JSONObject))
                try await p2pService.stopListening()
            case "connect":
                guard case let .list(objects) = RPCObject(request.params),
                      objects.count > 1,
                      case let .string(host) = objects[0],
                      case let .integer(port) = objects[1] else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("host,port"), description: "Host (string) and port (integer) are required.")))
                    return // or break?
                }
                // Attempt to find an inactive client.
                var clientService = P2PClientService?.none
                for service in p2pClientServices {
                    if await !service.status.isConnected {
                        clientService = service
                        break
                    }
                }
                guard let clientService else {
                    try await outbound.write(.init(id: request.id, error: .init(.applicationError("Maximum P2P client instances reached."))))
                    return
                }

                try await outbound.write(.init(id: request.id, result: .string("Connecting to peer @\(host):\(port)…") as JSONObject))
                await clientService.connect(host: host, port: port)
            case "disconnect":
                if case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .integer(localPort) = first {
                    try await outbound.write(.init(id: request.id, result: .string("Disconnecting from client @\(localPort)…") as RPCObject))

                    // Attempt to find a non-running client.
                    var clientService = P2PClientService?.none
                    for service in p2pClientServices {
                        if await service.status.localPort == localPort {
                            clientService = service
                        }
                    }
                    guard let clientService else {
                        try await outbound.write(.init(id: request.id, error: .init(.applicationError("No client connected @\(localPort)"))))
                        return
                    }

                    try await clientService.disconnect()
                } else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("Port (integer) is required."))))
                }
            case "generate-to":
                guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(publicKey) = first else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("publicKey"), description: "PublicKey (string) is required.")))
                    return
                }
                guard let publicKeyData = Data(hex: publicKey), let publicKey = PublicKey(compressed: publicKeyData) else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("publicKey"), description: "PublicKey hex encoding is is invalid.")))
                    return
                }
                await bitcoinService.generateTo(publicKey)
                try await outbound.write(.init(id: request.id, result: .string(await bitcoinService.headers.last!.hash.hex) as JSONObject))
            case "get-block":
                guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(blockIdentifierHex) = first else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("blockIdentifier"), description: "BlockIdentifier (string) is required.")))
                    return
                }
                guard let blockIdentifier = Data(hex: blockIdentifierHex), blockIdentifier.count == BlockHeader.identifierLength else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("blockIdentifier"), description: "BlockIdentifier hex encoding or length is invalid.")))
                    return
                }
                guard let blockInfo = await bitcoinService.getBlockInfo(blockIdentifier) else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("blockIdentifier"), description: "Block not found.")))
                    return
                }
                try await outbound.write(.init(id: request.id, result: .string(blockInfo.description) as JSONObject))
            case "get-transaction":
                guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(transactionIdentifierHex) = first else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("transactionIdentifier"), description: "TransactionIdentifier (string) is required.")))
                    return
                }
                guard let transactionIdentifier = Data(hex: transactionIdentifierHex), transactionIdentifier.count == BitcoinTransaction.identifierLength else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("transactionIdentifier"), description: "TransactionIdentifier hex encoding or length is invalid.")))
                    return
                }
                guard let transactionInfo = await bitcoinService.getTransactionInfo(transactionIdentifier) else {
                    try await outbound.write(.init(id: request.id, error: .init(.invalidParams("transactionIdentifier"), description: "Transaction not found.")))
                    return
                }
                try await outbound.write(.init(id: request.id, result: .string(transactionInfo.description) as JSONObject))
            case "get-blockchain-info":
                let blockchainInfo = await bitcoinService.getBlockchainInfo()
                try await outbound.write(.init(id: request.id, result: .string(blockchainInfo.description) as JSONObject))
            case "ping-all":
                await bitcoinNode.pingAll()
            case "request-headers":
                await bitcoinNode.requestHeaders()
            default:
                try await outbound.write(.init(id: request.id, error: .init(.invalidParams("method"), description: "Method `\(request.method)` does not exist.")))
            }
        }
    }
}
