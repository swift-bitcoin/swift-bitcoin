import ArgumentParser
import BitcoinTransport

extension NodeNetwork: Decodable, ExpressibleByArgument { }

struct Start: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Launch a Bitcoin node instance."
    )

    @Option(name: .shortAndLong, help: "The absolute path to either the folder containing Swift Bitcoin's configuration file or the configuration file itself, e.g. \"/some/folder/myConfig.json\".")
    var configPath = NodeConfig.defaultLocation

    @Option(name: .shortAndLong, help: "The P2P network to connect to. Defaults to what's specified in the configuration file. (default: \(NodeConfig.default.network))")
    var network: NodeConfig.Network?

    @Option(name: .shortAndLong, help: "Use in-memory for ephemeral in-memory data. Use default-path for storing data in the default location (will be created if it does not yet exist).")
    var dataLocationType: DataLocationType?

    @Option(name: [.customShort("q"), .long], help: "A custom absolute path to Swift Bitcoin's data directory (will be created if it does not yet exist).")
    var dataLocationPath: String?

    @Option(name: .long, help: "Listen for incoming connections on the peer-to-peer network at the speficied \"address:port\".")
    var bind: String?

    @Option(name: .long, help: "Connect to specified remote peers automatically on startup.")
    var connect: [String] = []

    @Option(name: .long, help: "Connect to randomly selected public peers automatically on startup. (default: \(NodeConfig.default.autoConnect))")
    var autoConnect: Bool?

    @Option(name: .shortAndLong, help: "The address to bind the RPC server to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeNetwork.testnet.defaultRPCPort) for \(NodeNetwork.testnet))")
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

        let bind: NodeConfig.BindSettings? = if let bind {
            if let (host, port) = IPv4Address.parse(bind) {
                .init(host: host, port: port)
            } else if let (host, port) = IPv6Address.parse(bind) {
                .init(host: host, port: port)
            } else {
                throw ValidationError("Invalid bind address format")
            }
        } else { config.bind }

        let connect: [NodeConfig.RemotePeer] = try connect.map { address in
            if let (host, port) = IPv4Address.parse(address) {
                .init(host: host, port: port)
            } else if let (host, port) = IPv6Address.parse(address) {
                .init(host: host, port: port)
            } else {
                throw ValidationError("Invalid bind address format")
            }
        }

        // WARNING: New configuration options need to be added here regardless of whether there is a command line parameter override!
        let resolvedConfig = NodeConfig(
            dataLocation: dataLocation ?? config.dataLocation,
            network: network ?? config.network,
            bind: bind,
            connect: connect + config.connect,
            autoConnect: autoConnect ?? config.autoConnect,
            logLevel: logLevel ?? config.logLevel,
            feeRate: config.feeRate,
            metrics: config.metrics,
            enableProfiling: config.enableProfiling
        )

        if resolvedConfig.network == .mainnet {
            throw ValidationError("Main network connectivity disabled during alpha development stage")
        }

        _ = try await ServerApp(resolvedConfig, host: host, port: port)
    }
}

enum DataLocationType: String, ExpressibleByArgument {
    case inMemory = "in-memory", defaultPath = "default-path"
}
