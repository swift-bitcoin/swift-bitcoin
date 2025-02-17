import Foundation
import Logging
import ServiceLifecycle
import NIOCore
import NIOPosix

import JSONRPC
import NIOJSONRPC
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain
import BitcoinTransport
import BitcoinRPC

private let logger = Logger(label: "swift-bitcoin.rpc")

actor RPCService: Service {

    init(host: String, port: Int, eventLoopGroup: EventLoopGroup, node: NodeService, blockchain: BlockchainService, p2pService: P2PService, p2pClients: [P2PClient]) {
        self.host = host
        self.port = port
        self.eventLoopGroup = eventLoopGroup
        self.node = node
        self.blockchain = blockchain
        self.p2pService = p2pService
        self.p2pClients = p2pClients
    }

    let host: String
    let port: Int
    let eventLoopGroup: EventLoopGroup
    let node: NodeService
    let blockchain: BlockchainService
    let p2pService: P2PService
    let p2pClients: [P2PClient]

    // Status and statistics
    private(set) var listening = false
    private(set) var overallConnections = 0
    private(set) var activeConnections = 0

    // State
    private var serviceGroup: ServiceGroup?

    func run() async throws {
        // Bootstraping server channel.
        let serverChannel = try await ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .bind(host: host, port: port) { connection in
                // This closure is called for every inbound connection.
                connection.eventLoop.makeCompletedFuture {
                    try connection.pipeline.syncOperations.addHandlers([
                        IdleStateHandler(readTimeout: TimeAmount.seconds(5)),
                        HalfCloseOnTimeout(),
                        ByteToMessageHandler(NewlineEncoder()),
                        MessageToByteHandler(NewlineEncoder()),
                        CodableCodec<JSONRequest, JSONResponse>()
                    ])
                    return try NIOAsyncChannel<JSONRequest, JSONResponse>(wrappingChannelSynchronously: connection)
                }
            }

        // Start listening
        try await withGracefulShutdownHandler {
            try await withThrowingDiscardingTaskGroup { @Sendable group in
                try await serverChannel.executeThenClose { serverChannelInbound in

                    logger.info("RPC server accepting incoming connections @ \(host):\(port)…")
                    await serviceUp()

                    for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                        logger.info("Incoming RPC connection from client @ \(String(describing: connectionChannel.channel.remoteAddress))")
                        await connectionMade()

                        group.addTask {
                            do {
                                try await connectionChannel.executeThenClose {
                                    for try await request in $0.cancelOnGracefulShutdown() {
                                        try await self.handleRequest(request, $0, $1)
                                    }
                                }
                            } catch {
                                logger.error("An unexpected error has occurred:\n\(error)")
                            }

                            logger.info("RPC server disconnected from client @ \(String(describing: connectionChannel.channel.remoteAddress)).")
                            await self.clientDisconnected()
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

    func setServiceGroup(_ serviceGroup: ServiceGroup) {
        precondition(self.serviceGroup == nil)
        self.serviceGroup = serviceGroup
    }

    private func serviceUp() {
        listening = true
    }

    private func connectionMade() {
        activeConnections += 1
        overallConnections += 1
    }

    private func clientDisconnected() {
        activeConnections -= 1
    }

    private func handleRequest(_ request: JSONRequest, _ inbound: NIOAsyncChannelInboundStream<JSONRequest>, _ outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws -> () {
        do {
            switch request.method {
            case StopCommand.method:
                try await rpcStop(request, outbound: outbound)
            case StartP2PCommand.method:
                try await rpcStartP2P(request, outbound: outbound)
            case StopP2PCommand.method:
                try await rpcStopP2P(request, outbound: outbound)
            case ConnectCommand.method:
                try await rpcConnect(request, outbound: outbound)
            case DisconnectPeerCommand.method:
                let command = try DisconnectPeerCommand(request)
                await command.run(node: node)
            case HelpCommand.method:
                let command = HelpCommand(request)
                try await outbound.write(command.run())
            case GetStatusCommand.method:
                try await rpcStatus(request, outbound: outbound)
            case GenerateToPubkeyCommand.method:
                let command = try GenerateToPubkeyCommand(request)
                try await outbound.write(command.run(blockchain: blockchain))
            case GetBlockHashCommand.method:
                let command = try GetBlockHashCommand(request)
                try await outbound.write(command.run(blockchain: blockchain))
            case GetBlockCommand.method:
                let command = try GetBlockCommand(request)
                try await outbound.write(command.run(blockchain: blockchain))
            case GetTransactionCommand.method:
                let command = try GetTransactionCommand(request)
                try await outbound.write(command.run(blockchain: blockchain))
            case GetBlockchainInfoCommand.method:
                let command = GetBlockchainInfoCommand(request)
                try await outbound.write(command.run(blockchain: blockchain))
            case GetMempoolCommand.method:
                let command = GetMempoolCommand(request)
                try await outbound.write(command.run(blockchain: blockchain))
            case GetPeerInfoCommand.method:
                let command = GetPeerInfoCommand(request)
                try await outbound.write(command.run(node: node))
            case SendTransactionCommand.method:
                let command = try SendTransactionCommand(request)
                try await command.run(blockchain: blockchain)
            default:
                try await outbound.write(.init(id: request.id, error: .init(.invalidParams("method"), description: "Method `\(request.method)` does not exist.")))
            }
        } catch let error as RPCError {
            try await outbound.write(.init(id: request.id, error: error))
        }
    }

    private func rpcStatus(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {

        let status = RPCServiceStatus(listening: listening, host: host, port: port, overallConnections: overallConnections, activeConnections: activeConnections)

        // Collect P2P Client Services' statuses in order
        let p2pClientStatus = await withTaskGroup(of: (Int, P2PClientStatus).self, returning: [P2PClientStatus].self) { group in
            for i in p2pClients.indices {
                group.addTask {
                    let status = await self.p2pClients[i].status
                    return (i, status)
                }
            }
            var items = [(Int, P2PClientStatus)]()
            for await var result in group {
                result.1.index = result.0 // Set the index inside the struct
                items.append(result)
            }
            return items.sorted(by: { $0.0 < $1.0 }).map(\.1) // Get rid of the tuple index
        }

        // Execute RPC Command
        let command = GetStatusCommand(request)
        try await outbound.write(command.run(rpcStatus: status, p2pStatus: await p2pService.status, p2pClientStatus: p2pClientStatus))
    }

    private func rpcStop(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
        _ = StopCommand(request) // Enforces precondition
        try await outbound.write(.init(id: request.id, result: .string("Stopping…") as JSONObject))
        await serviceGroup?.triggerGracefulShutdown()
    }

    private func rpcStartP2P(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
        let command = try StartP2PCommand(request)
        try await outbound.write(.init(id: request.id, result: .string("Staring P2P server on \(command.host):\(command.port)…") as JSONObject))
        await p2pService.start(host: command.host, port: command.port)
    }

    private func rpcStopP2P(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
        _ = StopP2PCommand(request) // Enforces precondition
        try await outbound.write(.init(id: request.id, result: .string("Stopping P2P server…") as JSONObject))
        try await p2pService.stopListening()
        await node.removeAllPeers(incomingOnly: true)
    }

    private func rpcConnect(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
        let command = try ConnectCommand(request)

        // Attempt to find an inactive client.
        var client = P2PClient?.none
        for c in p2pClients {
            if await !c.connected {
                client = c
                break
            }
        }
        guard let client else {
            try await outbound.write(.init(id: request.id, error: .init(.applicationError("Maximum P2P client instances reached."))))
            return
        }

        try await outbound.write(.init(id: request.id, result: .string("Connecting to peer @\(command.host):\(command.port)…") as JSONObject))
        await client.connect(host: command.host, port: command.port)
    }
}
