import Foundation
import ArgumentParser
import BitcoinBlockchain
import BitcoinTransport
import ServiceLifecycle
import NIOCore
import NIOPosix
import Logging

extension NodeNetwork: Decodable, ExpressibleByArgument { }

struct Start: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Launch a Bitcoin node instance."
    )

    @Option(name: .shortAndLong, help: "The absolute path to either the folder containing Swift Bitcoin's configuration file or the configuration file itself, e.g. \"/some/folder/myConfig.json\".")
    var configPath = NodeConfig.defaultLocation

    @Option(name: .shortAndLong, help: "The P2P network to connect to. Defaults to what's specified in the configuration file.")
    var network: NodeConfig.Network? // TODO: Eventually switch to testnet4 and then mainnet.

    @Option(name: .shortAndLong, help: "Use in-memory for ephemeral in-memory data. Use default-path for storing data in the default location (will be created if it does not yet exist).")
    var dataLocationType: DataLocationType?

    @Option(name: [.customShort("q"), .long], help: "A custom absolute path to Swift Bitcoin's data directory (will be created if it does not yet exist).")
    var dataLocationPath: String?

    @Option(name: .shortAndLong, help: "The address to bind the RPC server to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeNetwork.mainnet.defaultRPCPort) for \(NodeNetwork.mainnet))")
    var port: Int?

    @Option(name: .shortAndLong, help: "Log level.")
    var logLevel: NodeConfig.LogLevel?

    mutating func run() async throws {

        let dataLocation: NodeConfig.DataLocation? = if let dataLocationType, dataLocationPath == nil {
            switch dataLocationType {
            case .inMemory: .inMemory
            case .defaultPath: .defaultPath
            }
        } else if let dataLocationPath, dataLocationType == nil {
            .custom(path: dataLocationPath)
        } else if dataLocationType == nil, dataLocationPath == nil {
            nil
        } else {
            throw ValidationError("Either specify data-location-type or data-location-path.")
        }

        let config: NodeConfig
        do {
            try config = await NodeConfig.parse(configPath)
        } catch {
            throw ValidationError(error)
        }
        let resolvedConfig = NodeConfig(
            dataLocation: dataLocation ?? config.dataLocation,
            network: network ?? config.network,
            name: config.name,
            logLevel: logLevel ?? config.logLevel,
            feeRate: config.feeRate
        )

        try await launchNode(resolvedConfig, host: host, port: port)
    }
}

private func launchNode(_ config: NodeConfig, host: String, port: Int?) async throws {
    let network = NodeNetwork(config.network)
    let dataLocation = BlockchainService.Config.DataLocation(config.dataLocation)
    let port = port ?? network.defaultRPCPort

    var logger = Logger(label: "bcnode")
    logger.logLevel = .init(config.logLevel)

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard let configStringData = try? encoder.encode(config), let configString = String(data: configStringData, encoding: .utf8) else {
        fatalError("Could not encode configuration")
    }
    logger.info("\(configString)")

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

    let node = NodeService(blockchain: blockchain, config: .init(network: network), logger: logger)

    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    let p2pClients = (0 ..< 3).map { _ in
        P2PClient(eventLoopGroup: eventLoopGroup, node: node, logger: logger)
    }

    let p2pService = P2PService(eventLoopGroup: eventLoopGroup, node: node, logger: logger)

    let rpcService = RPCService(host: host, port: port, eventLoopGroup: eventLoopGroup, node: node, blockchain: blockchain, p2pService: p2pService, p2pClients: p2pClients, logger: logger)
    let serviceGroup = ServiceGroup(configuration: .init(
        services: [node] + p2pClients + [p2pService, rpcService],
        gracefulShutdownSignals: [.sigint, .sigterm],
        cancellationSignals: [.sigquit],
        logger: logger
    ))
    await rpcService.setServiceGroup(serviceGroup)
    try await serviceGroup.run()

    await blockchain.unsubscribeAll()
}

enum DataLocationType: String, ExpressibleByArgument {
    case inMemory = "in-memory", defaultPath = "default-path"
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
