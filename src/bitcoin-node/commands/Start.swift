import Foundation
import ArgumentParser
import BitcoinBlockchain
import BitcoinTransport
import ServiceLifecycle
import NIOCore
import NIOPosix

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

    @Option(name: [.customShort("l"), .long], help: "A custom absolute path to Swift Bitcoin's data directory (will be created if it does not yet exist).")
    var dataLocationPath: String?

    @Option(name: .shortAndLong, help: "The address to bind the RPC server to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeNetwork.mainnet.defaultRPCPort) for \(NodeNetwork.mainnet))")
    var port: Int?

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
            feeRate: config.feeRate
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let roundtrip = try? encoder.encode(resolvedConfig) else {
            throw ValidationError("Issue verifying decoding-encoding round trip.")
        }
        print(String(data: roundtrip, encoding: .utf8)!)

        let nodeNetwork = NodeNetwork(resolvedConfig.network)
        let nodeDataLocation = BlockchainService.Config.DataLocation(resolvedConfig.dataLocation)
        let port = port ?? nodeNetwork.defaultRPCPort
        try await launchNode(network: nodeNetwork, dataLocation: nodeDataLocation, host: host, port: port)
    }
}

private func launchNode(network: NodeNetwork, dataLocation: BlockchainService.Config.DataLocation, host: String, port: Int) async throws {
    let params: ConsensusParams = switch network {
    case .mainnet:
        .mainnet
    case .testnet:
        .testnet
    case .regtest:
        .regtest
    }
    let blockchain = BlockchainService(
        params: params,
        config: .init(dataLocation: dataLocation)
    )
    await blockchain.start()

    let node = NodeService(blockchain: blockchain)

    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    let p2pClients = (0 ..< 3).map { _ in
        P2PClient(eventLoopGroup: eventLoopGroup, node: node)
    }

    let p2pService = P2PService(eventLoopGroup: eventLoopGroup, node: node)

    let rpcService = RPCService(host: host, port: port, eventLoopGroup: eventLoopGroup, node: node, blockchain: blockchain, p2pService: p2pService, p2pClients: p2pClients)
    let serviceGroup = ServiceGroup(configuration: .init(
        services: [node] + p2pClients + [p2pService, rpcService],
        gracefulShutdownSignals: [.sigint, .sigterm],
        cancellationSignals: [.sigquit],
        logger: .init(label: "mainServiceGroup")
    ))
    await rpcService.setServiceGroup(serviceGroup)
    try await serviceGroup.run()

    await blockchain.stop()
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
