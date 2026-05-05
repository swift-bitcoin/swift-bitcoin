// Note: This file is required by the plugin `CopyConfigSources`.

struct NodeConfig: Codable {

    init(
        dataLocation: DataLocation = .defaultPath,
        network: Network = .mainnet,
        bind: BindSettings? = nil,
        connect: [RemotePeer] = [],
        autoConnect: Bool = true,
        logLevel: LogLevel = .info,
        feeRate: Int = 100,
        metrics: OTelMetrics? = nil,
        enableProfiling: Bool = false
    ) {
        self.dataLocation = dataLocation
        self.network = network
        self.bind = bind
        self.connect = connect
        self.autoConnect = autoConnect
        self.logLevel = logLevel
        self.feeRate = feeRate
        self.metrics = metrics
        self.enableProfiling = enableProfiling
    }

    let dataLocation: DataLocation
    let network: Network
    let bind: BindSettings?
    let connect: [RemotePeer]
    let autoConnect: Bool
    let logLevel: LogLevel
    let feeRate: Int

    /// Whether to report OpenTelemetry metrics, including system metrics.
    let metrics: OTelMetrics?
    let enableProfiling: Bool

    static let `default` = Self()

    init(from decoder: any Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dataLocation = try container.decodeIfPresent(NodeConfig.DataLocation.self, forKey: .dataLocation) ?? defaults.dataLocation
        self.network = try container.decodeIfPresent(NodeConfig.Network.self, forKey: .network) ?? defaults.network
        self.bind = try container.decodeIfPresent(BindSettings.self, forKey: .bind) ?? defaults.bind
        self.connect = try container.decodeIfPresent([RemotePeer].self, forKey: .connect) ?? defaults.connect
        self.autoConnect = try container.decodeIfPresent(Bool.self, forKey: .autoConnect) ?? defaults.autoConnect
        self.logLevel = try container.decodeIfPresent(LogLevel.self, forKey: .logLevel) ?? defaults.logLevel
        self.feeRate = try container.decodeIfPresent(Int.self, forKey: .feeRate) ?? defaults.feeRate
        self.metrics = try container.decodeIfPresent(NodeConfig.OTelMetrics.self, forKey: .metrics) ?? defaults.metrics
        self.enableProfiling = try container.decodeIfPresent(Bool.self, forKey: .enableProfiling) ?? defaults.enableProfiling
    }
}

extension NodeConfig {
    enum DataLocation: Codable {
        case inMemory, defaultPath, custom(path: String)
    }
}

extension NodeConfig {
    enum Network: String, Codable {
        case mainnet, testnet, regtest
    }
}

extension NodeConfig {
    enum LogLevel: String, Codable {
        case trace, debug, info, notice, warning, error, critical
    }
}

extension NodeConfig {

    /// OpenTelemetry metrics settings.
    struct OTelMetrics: Codable {
        init(endpoint: String = "http://localhost:4317") {
            self.endpoint = endpoint
        }

        /// The gRPC endpoint, e.g. `http://localhost:4317`.
        let endpoint: String
    }
}

extension NodeConfig {

    struct BindSettings: Codable {
        init(host: String? = nil, port: Int? = nil) {
            self.host = host
            self.port = port
        }

        /// `nil` means use default peer-to-peer binding IP address for the current network
        let host: String?

        /// `nil` means use default peer-to-peer binding TCP port for the current network
        let port: Int?
    }
}

extension NodeConfig {

    struct RemotePeer: Codable {
        init(host: String, port: Int?) {
            self.host = host
            self.port = port
        }

        /// IP address of the remote peer
        let host: String

        /// IP port of the remote peer. If `nil` it will use the current network's default
        let port: Int?
    }
}
