// Note: This file is required by the plugin `CopyConfigSources`.

struct NodeConfig: Encodable {

    init(
        network: Network = .mainnet,
        rpc: RPCSettings? = nil,
        dataLocation: DataLocation = .defaultPath,
        bind: BindSettings? = nil,
        connect: [RemotePeer] = [],
        autoConnect: Bool = true,
        logLevel: LogLevel = .info,
        metrics: OTelMetrics? = nil,
        enableProfiling: Bool = false,
        feeRate: Int = 100
    ) {
        self.network = network
        self.rpc = rpc ?? RPCSettings(host: "0.0.0.0", port: network.defaultRPCPort)
        self.dataLocation = dataLocation
        self.bind = bind
        self.connect = connect
        self.autoConnect = autoConnect
        self.logLevel = logLevel
        self.metrics = metrics
        self.enableProfiling = enableProfiling
        self.feeRate = feeRate
    }

    let network: Network
    let rpc: RPCSettings
    let dataLocation: DataLocation
    let bind: BindSettings?
    let connect: [RemotePeer]
    let autoConnect: Bool
    let logLevel: LogLevel

    /// Whether to report OpenTelemetry metrics, including system metrics.
    let metrics: OTelMetrics?
    let enableProfiling: Bool
    let feeRate: Int

    static let `default` = Self()

    enum CodingKeys: CodingKey {
        case network
        case rpc
        case dataLocation
        case bind
        case connect
        case autoConnect
        case logLevel
        case metrics
        case enableProfiling
        case feeRate
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.network, forKey: .network)
        try container.encode(self.rpc, forKey: .rpc)
        try container.encode(self.dataLocation, forKey: .dataLocation)
        try container.encodeIfPresent(self.bind, forKey: .bind)
        try container.encode(self.connect.map(\.description), forKey: .connect)
        try container.encode(self.autoConnect, forKey: .autoConnect)
        try container.encode(self.logLevel, forKey: .logLevel)
        try container.encodeIfPresent(self.metrics, forKey: .metrics)
        try container.encode(self.enableProfiling, forKey: .enableProfiling)
        try container.encode(self.feeRate, forKey: .feeRate)
    }
}

extension NodeConfig {
    enum Network: String, Codable {
        case mainnet, testnet, regtest

        var defaultRPCPort: Int {
            switch self {
            case .mainnet: 8332
            //case .testnet3: 18332
            case .testnet: 48332
            case .regtest: 18443
            // case .signet: 38332
            }
        }
    }
}

extension NodeConfig {
    struct RPCSettings: Codable {
        init(host: String, port: Int) {
            self.host = host
            self.port = port
        }

        let host: String
        let port: Int
    }
}

extension NodeConfig {
    enum DataLocation: Encodable {
        case inMemory, defaultPath, custom(path: String)

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .inMemory:
                try container.encode("in-memory")
            case .defaultPath:
                try container.encode("default-path")
            case let .custom(path: path):
                try container.encode("custom(\(path))")
            }
        }
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

    struct RemotePeer: Codable, CustomStringConvertible {

        init(host: String, port: Int?) {
            self.host = host
            self.port = port
        }

        /// IP address of the remote peer
        let host: String

        /// IP port of the remote peer. If `nil` it will use the current network's default
        let port: Int?

        var description: String {
            "\(host):\(port?.description ?? "")"
        }
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
