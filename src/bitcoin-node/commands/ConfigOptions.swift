import ArgumentParser

struct ConfigOptions: ParsableArguments {

    @Option(help: "The absolute path the directory containing Swift Bitcoin's configuration file(s).")
    var configPath = NodeConfig.defaultLocation

    @Option(help: "The P2P network to connect to. Defaults to what's specified in the configuration file. (default: \(NodeConfig.default.network))")
    var network: NodeConfig.Network?

    @Option(help: "The address to bind the RPC server to.")
    var rpcHost: String?

    @Option(help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeConfig.Network.mainnet.defaultRPCPort) for mainnet)")
    var rpcPort: Int?

    @Option(help: "Use in-memory for ephemeral in-memory data. Use default-path for storing data in the default location (will be created if it does not yet exist) or use \"custom(path)\" to specify a custom path")
    var dataLocation: String?

    @Option(help: "Listen for incoming connections on the peer-to-peer network at the speficied \"address:port\".")
    var bind: String?

    /// Address on which to listen for incoming connections on the peer-to-peer network
    @Option(help: .private)
    var bindHost: String?

    /// Port on which to listen for incoming connections on the peer-to-peer network
    @Option(help: .private)
    var bindPort: Int?

    @Option(help: "Connect to specified remote peers automatically on startup.")
    var connect: [String] = []

    /// The list of peer hosts to connect to.
    @Option(help: .private)
    var connectHost: [String] = []

    /// The list of peer ports corresponding to the specified peer hosts (--connect-host)
    @Option(help: .private)
    var connectPort: [Int] = []

    @Option(help: "Connect to randomly selected public peers automatically on startup. (default: \(NodeConfig.default.autoConnect))")
    var autoConnect: Bool?

    @Option(help: "Log level.")
    var logLevel: NodeConfig.LogLevel?

    @Option(defaultAsFlag: true, help: "Enable metrics with default settings")
    var metrics: Bool?

    @Option(help: "Metrics conenction endpoint")
    var metricsEndpoint: String?

    @Option(defaultAsFlag: true, help: "Enable remote profiling")
    var enableProfiling: Bool?

    @Option(help: "Minimum fee rate to accept transactions")
    var feeRate: Int?
}
