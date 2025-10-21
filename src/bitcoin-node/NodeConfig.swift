// Note: This file is required by the plugin `CopyConfigSources`.

struct NodeConfig: Codable {

    init(
        dataLocation: DataLocation = .inMemory,
        network: Network = .regtest,
        name: String = "SwiftBitcoin",
        logLevel: LogLevel = .info,
        feeRate: Int = 100,
        metrics: StatsdMetrics? = nil,
        enableProfiling: Bool = false
    ) {
        self.dataLocation = dataLocation
        self.network = network
        self.name = name
        self.logLevel = logLevel
        self.feeRate = feeRate
        self.metrics = metrics
        self.enableProfiling = enableProfiling
    }

    let dataLocation: DataLocation
    let network: Network
    let name: String
    let logLevel: LogLevel
    let feeRate: Int
    let metrics: StatsdMetrics?
    let enableProfiling: Bool

    static let `default` = Self()

    init(from decoder: any Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dataLocation = try container.decodeIfPresent(NodeConfig.DataLocation.self, forKey: .dataLocation) ?? defaults.dataLocation
        self.network = try container.decodeIfPresent(NodeConfig.Network.self, forKey: .network) ?? defaults.network
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? defaults.name
        self.logLevel = try container.decodeIfPresent(LogLevel.self, forKey: .logLevel) ?? defaults.logLevel
        self.feeRate = try container.decodeIfPresent(Int.self, forKey: .feeRate) ?? defaults.feeRate
        self.metrics = try container.decodeIfPresent(NodeConfig.StatsdMetrics.self, forKey: .metrics) ?? defaults.metrics
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

    struct StatsdMetrics: Codable {
        init(host: String = "localhost", port: Int = 8125) {
            self.host = host
            self.port = port
        }

        let host: String
        let port: Int
    }
}
