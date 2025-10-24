import Foundation
import JSONRPC
import BitcoinBlockchain
import BitcoinTransport
import Logging
import Metrics
import StatsdClient
import ProfileRecorderServer
import ServiceLifecycle
import NIOCore
import NIOPosix

actor ServerApp {

    init(_ config: NodeConfig, host: String, port: Int?) async throws {
        let network = NodeNetwork(config.network)
        let dataLocation = BlockchainService.Config.DataLocation(config.dataLocation)
        let port = port ?? network.defaultRPCPort

        var logger = Logger(label: "bcnode")
        logger.logLevel = .init(config.logLevel)
        self.logger = logger

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let configStringData = try? encoder.encode(config), let configString = String(data: configStringData, encoding: .utf8) else {
            fatalError("Could not encode configuration")
        }
        logger.info("\(configString)")

        if config.enableProfiling {
            logger.info("Profiling capability enabled as per configuration")
            async let _ = ProfileRecorderServer(configuration: .parseFromEnvironment()).runIgnoringFailures(logger: logger)
        }

        let statsdClient: StatsdClient?
        if let statsd = config.metrics {
            logger.info("Metrics enabled as per statsd configuration: UDP+statsd://\(statsd.host):\(statsd.port)")
            let client = try StatsdClient(host: statsd.host, port: statsd.port)
            MetricsSystem.bootstrap(client)
            statsdClient = client
        } else {
            statsdClient = nil
        }

        let params: ConsensusParams = switch network {
        case .mainnet:
            .mainnet
        case .testnet:
            .testnet
        case .regtest:
            .regtest
        }
        let blockchain = try await BlockchainService(
            params: params,
            config: .init(dataLocation: dataLocation),
            logger: logger
        )

        node = NodeService(blockchain: blockchain, config: .init(network: network), logger: logger)

        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        rpcService = RPCService(host: host, port: port, eventLoopGroup: eventLoopGroup, node: node, blockchain: blockchain, logger: logger)

        var services: [ServiceGroupConfiguration.ServiceConfiguration] = []

        services.append(.init(service: node, successTerminationBehavior: .gracefullyShutdownGroup, failureTerminationBehavior: .cancelGroup))

        if let bind = config.bind {
            let p2pService = P2PService(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: bind.host ?? "0.0.0.0", port: bind.port ?? network.defaultP2PPort)
            self.p2pService = p2pService
            services.append(.init(service: p2pService, successTerminationBehavior: .ignore, failureTerminationBehavior: .gracefullyShutdownGroup))
        }

        pendingConnect = config.connect.map {
            ($0.host, $0.port ?? network.defaultP2PPort)
        }

        if let (host, port) = pendingConnect.first {
            let p2pClient = await P2PClient(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: host, port: port)
            p2pClients[p2pClient.id] = p2pClient
            services.append(.init(service: p2pClient, successTerminationBehavior: .ignore, failureTerminationBehavior: .gracefullyShutdownGroup))
        }

        services.append(.init(service: rpcService, successTerminationBehavior: .gracefullyShutdownGroup, failureTerminationBehavior: .cancelGroup))

        serviceGroup = ServiceGroup(configuration: .init(
            services: services,
            gracefulShutdownSignals: [.sigint, .sigterm],
            cancellationSignals: [.sigquit],
            logger: logger
        ))

        // All instance variables initialized, time to set some call backs

        await rpcService.setServerApp(self)

        if let client = p2pClients.values.first {
            await client.setConnectHandler { id in
                await self.connectNext(id)
            } onDisconnect: { id in
                await self.connectNext(id, previousFailed: true)
            }
        }

        // After the following line the app will suspend indefinitely
        try await serviceGroup.run()

        // Execution will only continue here after service group shuts down

        await blockchain.shutdown()

        if let statsdClient {
            logger.info("Shutting down statsd client…")
            statsdClient.shutdown { [logger] error in
                if let error {
                    logger.error("\(error.localizedDescription)")
                    return
                }
                logger.info("Statsd client shut down")
            }
        }
    }

    private let logger: Logger
    private let node: NodeService
    private let rpcService: RPCService
    private var p2pService: P2PService? = nil
    private var p2pClients = [UUID: P2PClient]()

    private var pendingConnect: [(String, Int)] // Address / port

    private let eventLoopGroup: EventLoopGroup
    private let serviceGroup: ServiceGroup

    func rpcStatus() async -> StatusRPC.Result {

        let status = await rpcService.status

        // Collect P2P Client Services' statuses in order
        let p2pClientStatus = await withTaskGroup(of: (Int, StatusRPC.Result.P2PClient).self, returning: [StatusRPC.Result.P2PClient].self) { group in
            for client in p2pClients.values {
                group.addTask {
                    let status = await client.status
                    return (status.peerID, status)
                }
            }
            // Let's sort clients by their ID
            var items = [(Int, StatusRPC.Result.P2PClient)]()
            for await result in group {
                // result.1.peerID = result.0 // Set the peerID inside the struct
                items.append(result)
            }
            return items.sorted(by: { $0.0 < $1.0 }).map(\.1) // Get rid of the tuple index
        }

        let p2pStatus = await p2pService?.status ?? .init(listening: false, host: nil, port: nil, overallConnections: -1, sessionConnections: -1, activeConnections: -1)

        // Execute RPC Command
        return await StatusRPC().run(rpcStatus: status, p2pStatus: p2pStatus, p2pClientStatus: p2pClientStatus)
    }

    func rpcStop() async {
        await serviceGroup.triggerGracefulShutdown()
    }

    func rpcConnect(_ params: ConnectRPC.Params) async throws(JSONRPCResponse.Error) -> ConnectRPC.Result {
        let service = await P2PClient(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: params.host, port: params.port) { _ in } onDisconnect: { id in
            await self.clearPeer(id)
        }
        p2pClients[service.id] = service
        let config = ServiceGroupConfiguration.ServiceConfiguration(service: service, successTerminationBehavior: .ignore)
        await serviceGroup.addServiceUnlessShutdown(config)
        return service.peerID
    }

    func rpcStartP2P(_ params: StartP2PRPC.Params) async {
        guard p2pService == nil else {
            logger.warning("Already listening for incoming peer-to-peer connections")
            return
        }
        let p2pService = P2PService(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: params.host, port: params.port)
        self.p2pService = p2pService
        let config = ServiceGroupConfiguration.ServiceConfiguration(service: p2pService, successTerminationBehavior: .ignore)
        await serviceGroup.addServiceUnlessShutdown(config)
    }

    func rpcStopP2P() async throws(JSONRPCResponse.Error) {
        guard let p2pService else {
            logger.warning("Peer-to-peer service already stopped – ignoring")
            return
        }
        do {
            try await p2pService.stopListening()
        } catch {
            throw .init(.internalError, error.localizedDescription)
        }
        await node.removeAllPeers(incomingOnly: true)
        self.p2pService = nil
    }

    private func connectNext(_ id: UUID, previousFailed: Bool = false) async {
        guard let client = p2pClients[id] else {
            logger.error("Missing client from pending auto-connect list, clearing remainder of list")
            pendingConnect = []
            return
        }
        if previousFailed {
            clearPeer(id)
        } else {
            // Replace the handler
            await client.setConnectHandler { _ in } onDisconnect: { id in await self.clearPeer(id) }
        }
        guard let (host, port) = pendingConnect.first, host == client.remoteHost, port == client.remotePort else {
            // Should never happen, if it does consider keeping a separate list for "in progress" client auto connections different from the pending auto-connections
            logger.error("Client mismatch in pending auto-connect list, clearing remainder of list")
            pendingConnect = []
            return
        }
        pendingConnect.removeFirst()
        guard let (host, port) = pendingConnect.first else { return } // No more auto connections

        let service = await P2PClient(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: host, port: port) { id in
            await self.connectNext(id)
        } onDisconnect: { id in
            await self.connectNext(id, previousFailed: true)
        }
        p2pClients[service.id] = service
        let config = ServiceGroupConfiguration.ServiceConfiguration(service: service, successTerminationBehavior: .ignore)
        await serviceGroup.addServiceUnlessShutdown(config)
    }

    private func clearPeer(_ id: UUID) {
        p2pClients[id] = nil
    }
}

extension BlockchainService.Config.DataLocation {

    init(_ dataLocation: NodeConfig.DataLocation) {
        self = switch dataLocation {
        case .inMemory: .inMemory
        case .defaultPath: .defaultPath
        case let .custom(path: path): .custom(path: path)
        }
    }
}
