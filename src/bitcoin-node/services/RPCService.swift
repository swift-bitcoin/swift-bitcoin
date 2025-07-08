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

    init(host: String, port: Int, eventLoopGroup: EventLoopGroup, node: NodeService, blockchain: BlockchainService, p2pService: P2PService, p2pClients: [P2PClient], logger: Logger) {
        self.host = host
        self.port = port
        self.eventLoopGroup = eventLoopGroup
        self.node = node
        self.blockchain = blockchain
        self.p2pService = p2pService
        self.p2pClients = p2pClients
        self.logger = logger
    }

    let host: String
    let port: Int
    let eventLoopGroup: EventLoopGroup
    let node: NodeService
    let blockchain: BlockchainService
    let p2pService: P2PService
    let p2pClients: [P2PClient]
    let logger: Logger

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

    private func handleRequest(_ request: JSONRPCRequest, _ inbound: NIOAsyncChannelInboundStream<JSONRPCRequest>, _ outbound: NIOAsyncChannelOutboundWriter<JSONRPCResponse>) async throws -> () {
        do {
            switch request.params {
            case .help(let params):
                let result = try await HelpRPC(params).run()
                try await outbound.write(.init(id: request.id, result: .help(result)))
            case .status:
                let result = await rpcStatus()
                try await outbound.write(.init(id: request.id, result: .status(result)))
            case .stop:
                await rpcStop()
            case .startP2P(let params):
                await rpcStartP2P(params)
            case .stopP2P:
                try await rpcStopP2P()
            case .connect(let params):
                let result = try await rpcConnect(params)
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
            case .generateToAddress(let params):
                let result = try await GenerateToAddressRPC(params).run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .generateToAddress(result)))
            case .getBlockchainInfo:
                let result = await GetBlockchainInfoRPC().run(blockchain: blockchain)
                try await outbound.write(.init(id: request.id, result: .getBlockchainInfo(result)))
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
            }
        } catch let error as JSONRPCResponse.Error {
            // try await outbound.write(.init(id: request.id, error: error))
            try await outbound.write(.init(id: request.id, error: error))
        }
    }

    private func rpcStatus() async -> StatusRPC.Result {

        let status = StatusRPC.Result.RPCService(listening: listening, host: host, port: port, overallConnections: overallConnections, activeConnections: activeConnections)

        // Collect P2P Client Services' statuses in order
        let p2pClientStatus = await withTaskGroup(of: (Int, StatusRPC.Result.P2PClient).self, returning: [StatusRPC.Result.P2PClient].self) { group in
            for i in p2pClients.indices {
                group.addTask {
                    let status = await self.p2pClients[i].status
                    return (i, status)
                }
            }
            var items = [(Int, StatusRPC.Result.P2PClient)]()
            for await var result in group {
                result.1.index = result.0 // Set the index inside the struct
                items.append(result)
            }
            return items.sorted(by: { $0.0 < $1.0 }).map(\.1) // Get rid of the tuple index
        }

        // Execute RPC Command
        return await StatusRPC().run(rpcStatus: status, p2pStatus: await p2pService.status, p2pClientStatus: p2pClientStatus)
    }

    private func rpcStop() async {
        await serviceGroup?.triggerGracefulShutdown()
    }

    private func rpcStartP2P(_ params: StartP2PRPC.Params) async {
        await p2pService.start(host: params.host, port: params.port)
    }

    private func rpcStopP2P() async throws(JSONRPCResponse.Error) {
        do {
            try await p2pService.stopListening()
        } catch {
            throw .init(.internalError, error.localizedDescription)
        }
        await node.removeAllPeers(incomingOnly: true)
    }

    private func rpcConnect(_ params: ConnectRPC.Params) async throws(JSONRPCResponse.Error) -> ConnectRPC.Result {
        // Attempt to find an inactive client.
        var client = P2PClient?.none
        for c in p2pClients {
            if await !c.connected {
                client = c
                break
            }
        }
        guard let client else {
            throw .init(.internalError, "Maximum P2P client instances reached.")
        }
        await client.connect(host: params.host, port: params.port)
        return UUID().uuidString // FIXME: Find a way to return real peer ID
    }
}
