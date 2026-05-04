import Foundation
import JSONRPC
import BitcoinBlockchain
import BitcoinTransport
import Logging
import Metrics
import ProfileRecorderServer
import ServiceLifecycle
import NIOCore
import NIOPosix

/// A top-level actor that composes and orchestrates the node’s services.
///
/// ServerApp is responsible for:
/// - Bootstrapping logging, metrics (StatsD), and optional profiling support.
/// - Creating and wiring core services (BlockchainService, NodeService).
/// - Hosting the JSON-RPC server (RPCService).
/// - Managing the peer-to-peer listener (P2PService) and outbound peer clients (P2PClient).
/// - Coordinating service lifecycles via ServiceLifecycle’s ServiceGroup, including graceful shutdown.
///
/// Initialization parses the provided NodeConfig, selects the appropriate network
/// (mainnet, testnet, regtest), prepares persistent data location, and builds the
/// service graph. It then starts the service group and suspends until shutdown signals
/// are received (SIGINT/SIGTERM) or a fatal failure occurs.
///
/// Concurrency
/// - This type is an actor. All mutable state (peer clients, pending connects, etc.)
///   is protected by the actor’s isolation.
/// - Services that run on SwiftNIO event loops are created and managed here, while
///   inbound RPC calls into ServerApp hop across actor boundaries as needed.
///
/// Lifecycle
/// - After initialization completes, ServerApp awaits `serviceGroup.run()`; execution
///   resumes only when services shut down.
/// - On shutdown, the blockchain service is asked to shut down and any metrics client
///   is cleanly closed.
///
/// Configuration
/// - Network and ports come from NodeConfig and NodeNetwork defaults:
///   - RPC: defaults to the network’s default RPC port unless overridden by the init `port`.
///   - P2P: defaults to the network’s default P2P port unless overridden via NodeConfig.BindSettings.
/// - Metrics (StatsD) are enabled when NodeConfig.metrics is present.
/// - Profiling is optionally enabled when NodeConfig.enableProfiling is true.
/// - Auto-connect peers can be randomly selected from public peers or manually provided via NodeConfig.connect; ServerApp will chain
///   through these addresses, advancing on successful connection or failure.
///
/// Exposed RPC operations handled directly by this actor
/// - status (StatusRPC): Aggregates status from RPCService, P2PService, and all P2PClient instances.
/// - stop: Triggers a graceful shutdown of the entire service group.
/// - connect (ConnectRPC): Creates and starts a new outbound peer client and returns its PeerID.
/// - start-p2p (StartP2PRPC): Starts a listener for inbound peer connections (if not already running).
/// - stopP2P: Stops the P2P listener and removes all inbound peers.
///
/// - Note: This actor owns the EventLoopGroup used by RPC and P2P services and must
///   outlive them for the duration of the process.
///
/// - SeeAlso:
///   - NodeConfig for configuration options
///   - RPCService for JSON-RPC hosting
///   - P2PService and P2PClient for peer-to-peer networking
///   - StatusRPC, ConnectRPC, StartP2PRPC for RPC command interfaces
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

        let telemetryService: ServiceGroup?
        let metricsFactory: (any MetricsFactory)?
        if let metricsConfig = config.metrics {
            logger.info("Metrics enabled as per OTel configuration with endpoint \(metricsConfig.endpoint)")
            // Initialize all telemetry services
            (telemetryService, metricsFactory) = try makeTelemetryService(
                logger: logger,
                serviceName: "swift-bitcoin",
                endpoint: metricsConfig.endpoint
            )
        } else {
            telemetryService = nil
            metricsFactory = nil
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

        if let telemetryService {
            services.append(.init(service: telemetryService))
        }

        services.append(.init(service: node, successTerminationBehavior: .gracefullyShutdownGroup, failureTerminationBehavior: .cancelGroup))

        if let bind = config.bind {
            let p2pService = P2PService(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: bind.host ?? "0.0.0.0", port: bind.port ?? network.defaultP2PPort)
            self.p2pService = p2pService
            services.append(.init(service: p2pService, successTerminationBehavior: .ignore, failureTerminationBehavior: .gracefullyShutdownGroup))
        }

        services.append(.init(service: rpcService, successTerminationBehavior: .gracefullyShutdownGroup, failureTerminationBehavior: .cancelGroup))

        serviceGroup = ServiceGroup(configuration: .init(
            services: services,
            gracefulShutdownSignals: [.sigint, .sigterm],
            cancellationSignals: [.sigquit],
            logger: logger
        ))

        let autoConnectAddresses = if config.autoConnect && config.connect.isEmpty {
            network.autoconnectPeers.shuffled()
        } else {
            config.connect.map {
                ($0.host, $0.port ?? network.defaultP2PPort)
            }
        }

        let autoConnectService = AutoConnectService(addresses: autoConnectAddresses, services: serviceGroup, eventLoopGroup: eventLoopGroup, node: node, logger: logger)
        await serviceGroup.addServiceUnlessShutdown(.init(service: autoConnectService, successTerminationBehavior: .ignore, failureTerminationBehavior: .cancelGroup))

        // All instance variables initialized, time to set some call backs
        await rpcService.setServerApp(self)

        if let metricsFactory {
            // Use withMetricsFactory to make the OTel factory available as a task-local
            // for any Metric objects created during the service group's run
            try await withMetricsFactory(metricsFactory) {
                try await serviceGroup.run()
            }
        } else {
            // After the following line the app will suspend indefinitely
            try await serviceGroup.run()
        }

        // Execution will only continue here after service group shuts down

        await blockchain.shutdown()
    }

    private let logger: Logger
    private let node: NodeService
    private let rpcService: RPCService
    private var p2pService: P2PService? = nil

    private let eventLoopGroup: EventLoopGroup
    private let serviceGroup: ServiceGroup

    /// Aggregates a snapshot of the node’s status across services.
    ///
    /// - Returns: A StatusRPC.Result that includes:
    ///   - RPC server listening state and connection counters.
    ///   - P2P listener state (if running) and connection counters.
    ///   - A sorted list of outbound P2P client statuses by PeerID.
    func rpcStatus() async -> StatusRPC.Result {

        let status = await rpcService.status

        let p2pClientStatus = await node.outgoingPeers.map {
            StatusRPC.Result.P2PClient(peerID: $0.id, connected: true, remoteHost: $0.host, remotePort: $0.port, localPort: -1)
        }

        // Collect P2P Client Services' statuses in order
        /*
         let p2pClientStatus = await withTaskGroup(of: (PeerID, StatusRPC.Result.P2PClient).self, returning: [StatusRPC.Result.P2PClient].self) { group in
         for client in p2pClients.values {
         group.addTask {
         let status = await client.status
         return (status.peerID, status)
         }
         }
         // Let's sort clients by their ID
         var items = [(PeerID, StatusRPC.Result.P2PClient)]()
         for await result in group {
         // result.1.peerID = result.0 // Set the peerID inside the struct
         items.append(result)
         }
         return items.sorted(by: { $0.0 < $1.0 }).map(\.1) // Get rid of the tuple index
         }
         */

        let p2pStatus = await p2pService?.status ?? .init(listening: false, host: nil, port: nil, overallConnections: -1, sessionConnections: -1, activeConnections: -1)

        // Execute RPC Command
        return await StatusRPC().run(rpcStatus: status, p2pStatus: p2pStatus, p2pClientStatus: p2pClientStatus)
    }

    /// Initiates graceful shutdown of the entire service group.
    ///
    /// This is invoked by the JSON-RPC `stop` command and results in the RPC server
    /// closing, P2P services stopping, and the blockchain service shutting down cleanly.
    func rpcStop() async {
        await serviceGroup.triggerGracefulShutdown()
    }

    /// Connects to a remote peer and starts a new outbound P2P client.
    ///
    /// - Parameter params: Host and port for the remote peer (ConnectRPC.Params).
    /// - Returns: The new peer’s numeric ID (PeerID) on success.
    /// - Throws: JSONRPCResponse.Error if the connection cannot be started.
    func rpcConnect(_ params: ConnectRPC.Params) async throws(JSONRPCResponse.Error) -> ConnectRPC.Result {
        let service = await P2PClient(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: params.host, port: params.port)
        let config = ServiceGroupConfiguration.ServiceConfiguration(service: service, successTerminationBehavior: .ignore, failureTerminationBehavior: .gracefullyShutdownGroup) // TODO: Maybe do not shut down when we timeout on an outgoing peer?
        await serviceGroup.addServiceUnlessShutdown(config)
        return service.peerID
    }

    /// Starts the inbound P2P listener if it is not already running.
    ///
    /// - Parameter params: The bind host and port for the P2P listener (StartP2PRPC.Params).
    /// - Note: If the listener is already running, this call logs a warning and does nothing.
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

    /// Stops the inbound P2P listener and clears all inbound peers.
    ///
    /// - Throws: JSONRPCResponse.Error if the listener cannot be stopped.
    /// - Note: If the listener is already stopped, this call logs a warning and returns.
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
}

extension BlockchainService.Config.DataLocation {

    /// Maps the application’s NodeConfig.DataLocation to the blockchain service’s data location.
    ///
    /// - Parameter dataLocation: The app-level data location setting.
    /// - Note: `.custom(path:)` is forwarded as-is to the underlying service.
    init(_ dataLocation: NodeConfig.DataLocation) {
        self = switch dataLocation {
        case .inMemory: .inMemory
        case .defaultPath: .defaultPath
        case let .custom(path: path): .custom(path: path)
        }
    }
}

import AsyncAlgorithms
import Instrumentation
import Logging
import Metrics
import OTel
import ServiceLifecycle
import SystemMetrics
import UnixSignals

func makeTelemetryService(logger: Logger, serviceName: String, endpoint: String) throws -> (service: ServiceGroup, metricsFactory: any MetricsFactory) {
    var otelConfig = OTel.Configuration.default
    otelConfig.metrics.otlpExporter.protocol = .grpc
    otelConfig.metrics.otlpExporter.endpoint = endpoint
    print("Brr metrics proto \(otelConfig.metrics.otlpExporter.protocol) endpoint \(otelConfig.metrics.otlpExporter.endpoint)")
    otelConfig.logs.enabled = false
    otelConfig.metrics.enabled = true
    otelConfig.traces.enabled = false
    otelConfig.serviceName = serviceName
    let otelMetricsBackend = try OTel.makeMetricsBackend(configuration: otelConfig)

    // Configure SystemMetrics monitoring with an explicit metrics factory
    let systemMetricsMonitor = SystemMetricsMonitor(
        configuration: .init(pollInterval: .seconds(30)),
        metricsFactory: otelMetricsBackend.factory,
        logger: logger
    )

    // Create a named service group
    let serviceGroup = ServiceGroup(
        services: [
            otelMetricsBackend.service,
            systemMetricsMonitor,
        ],
        logger: logger,
    )
    let namedServiceConfiguration = ServiceGroupConfiguration.ServiceConfiguration(
        service: serviceGroup,
        serviceName: "Telemetry"
    )
    let serviceGroupConfiguration = ServiceGroupConfiguration(
        services: [namedServiceConfiguration],
        logger: logger
    )
    return (ServiceGroup(configuration: serviceGroupConfiguration), otelMetricsBackend.factory)
}
