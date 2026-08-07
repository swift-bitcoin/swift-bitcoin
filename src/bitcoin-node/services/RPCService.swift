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

actor RPCService: Service {

    init(host: String, port: Int, eventLoopGroup: EventLoopGroup, node: NodeService, blockchain: BlockchainService, logger: Logger) {
        self.host = host
        self.port = port
        self.eventLoopGroup = eventLoopGroup
        self.node = node
        self.blockchain = blockchain
        self.logger = logger
    }

    let host: String
    let port: Int
    let eventLoopGroup: EventLoopGroup
    let node: NodeService
    let blockchain: BlockchainService
    let logger: Logger

    // Status and statistics
    private(set) var listening = false
    private(set) var overallConnections = 0
    private(set) var activeConnections = 0

    // State
    private var app: ServerApp!

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
                        IdleStateHandler(readTimeout: TimeAmount.seconds(1)),
                        HalfCloseOnTimeout(),
                        ByteToMessageHandler(NewlineEncoder()),
                        ByteToMessageHandler(RequestDecoder()),
                        MessageToByteHandler(NewlineEncoder()),
                        MessageToByteHandler(ResponseEncoder()),
                    ])
                    return try NIOAsyncChannel<JSONRPCRequest, JSONRPCResponse>(wrappingChannelSynchronously: connection)
                }
            }

        // Start listening
        try await withGracefulShutdownHandler {
            try await withThrowingDiscardingTaskGroup { @Sendable [logger] group in
                try await serverChannel.executeThenClose { [logger] serverChannelInbound in

                    logger.info("RPC server accepting incoming connections @ \(host):\(port)…")
                    await serviceUp()

                    for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                        logger.info("Incoming RPC connection from client @ \(String(describing: connectionChannel.channel.remoteAddress))")
                        await connectionMade()

                        group.addTask { [logger] in
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
        } onGracefulShutdown: { [logger] in
            logger.info("RPC server shutting down gracefully…")
        }
    }

    func setServerApp(_ app: ServerApp) {
        precondition(self.app == nil)
        self.app = app
    }

    func unsetServerApp() {
        precondition(self.app != nil)
        self.app = nil
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

    private func handleRequest(_ request: JSONRPCRequest, _ inbound: NIOAsyncChannelInboundStream<JSONRPCRequest>, _ outbound: NIOAsyncChannelOutboundWriter<JSONRPCResponse>) async throws -> () {
        do {
            switch request.params {
            case .help(let params):
                let result = try await HelpRPC(params).run()
                try await outbound.write(.init(id: request.id, result: .help(result)))
            case .status:
                let result = await app.rpcStatus()
                try await outbound.write(.init(id: request.id, result: .status(result)))
            case .stop:
                await app.rpcStop()
            case .startP2P(let params):
                await app.rpcStartP2P(params)
            case .stopP2P:
                try await app.rpcStopP2P()
            case .connect(let params):
                let result = try await app.rpcConnect(params)
                try await outbound.write(.init(id: request.id, result: .connect(result)))
            case .disconnectPeer(let params):
                let result = await DisconnectPeerRPC(params).run(node: node)
                try await outbound.write(.init(id: request.id, result: .disconnectPeer(result)))
            case .getBlockHash(let params):
                let result = try await GetBlockHashRPC(params).run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getBlockHash(result)))
            case .getBlock(let params):
                let result = try await GetBlockRPC(params).run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getBlock(result)))
            case .getHeader(let params):
                let result = try await GetHeaderRPC(params).run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getHeader(result)))
            case .generateToAddress(let params):
                let result = try await GenerateToAddressRPC(params).run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .generateToAddress(result)))
            case .getBlockchainInfo:
                let result = await GetBlockchainInfoRPC().run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getBlockchainInfo(result)))
            case .getChainTips:
                let result = await GetChainTipsRPC().run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getChainTips(result)))
            case .getMempool:
                let result = await GetMempoolRPC().run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getMempool(result)))
            case .getPeerInfo:
                let result = await GetPeerInfoRPC().run(node: node)
                try await outbound.write(.init(id: request.id, result: .getPeerInfo(result)))
            case .getTransaction(let params):
                let result = try await GetTransactionRPC(params).run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getTransaction(result)))
            case .sendTransaction(let params):
                let result = try await SendTransactionRPC(params).run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .sendTransaction(result)))
            case .reindex:
                await ReindexRPC().run(blockchain: blockchain)
            case .reindexStatus:
                let result = await ReindexStatusRPC().run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .reindexStatus(result)))
            case .reindexStop:
                await ReindexStopRPC().run(blockchain: blockchain)
            }
        } catch let error as JSONRPCResponse.Error {
            // try await outbound.write(.init(id: request.id, error: error))
            try await outbound.write(.init(id: request.id, error: error))
        }
    }

    var status: StatusRPC.Result.RPCService {
        StatusRPC.Result.RPCService(listening: listening, host: host, port: port, overallConnections: overallConnections, activeConnections: activeConnections)
    }
}
