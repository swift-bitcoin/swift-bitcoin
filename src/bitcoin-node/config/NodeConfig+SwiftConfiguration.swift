import Configuration

extension NodeConfig {

    init(_ config: ConfigReader) throws(ConfigError) {
        let network = if let networkString = config.string(forKey: "network"), let n = Network(rawValue: networkString) {
            n
        } else {
            NodeConfig.default.network
        }

        let rpcHost = config.string(forKey: "rpc.host", default: NodeConfig.default.rpc.host)
        let rpcPort = config.int(forKey: "rpc.port", default: NodeConfig.default.rpc.port)
        let rpc = NodeConfig.RPCSettings(host: rpcHost, port: rpcPort)

        let dataLocation = if let dataLocationString = config.string(forKey: "dataLocation"), let dl = DataLocation(dataLocationString) {
            dl
        } else {
            NodeConfig.default.dataLocation
        }

        guard config.string(forKey: "bind") == nil || (config.string(forKey: "bind.host") == nil && config.string(forKey: "bind.port") == nil) else {
            throw .conflictingArguments("bind", "bind.host/port")
        }

        let bind = if let bindString = config.string(forKey: "bind"), let b = BindSettings(bindString) {
            b
        } else if let bindHost = config.string(forKey: "bind.host") {
            BindSettings(host: bindHost, port: config.int(forKey: "bind.port"))
        } else {
            NodeConfig.default.bind
        }

        let connectPartA = config.stringArray(forKey: "connect")?.compactMap(RemotePeer.init)
        let connectPartB: [RemotePeer]? = if let connectHosts = config.stringArray(forKey: "connect.host"), let connectPorts = config.intArray(forKey: "connect.port") {
            zip(connectHosts, connectPorts).map { RemotePeer(host: $0.0, port: $0.1)}
        } else {
            nil
        }
        let connect = if connectPartA == nil, connectPartB == nil {
            NodeConfig.default.connect
        } else {
            (connectPartA ?? []) + (connectPartB ?? [])
        }

        let autoConnect = config.bool(forKey: "autoConnect", default: NodeConfig.default.autoConnect)

        let logLevel = if let logLevelString = config.string(forKey: "logLevel"), let ll = LogLevel(rawValue: logLevelString) {
            ll
        } else {
            NodeConfig.default.logLevel
        }

        let metrics = if let metricsEndpoint = config.string(forKey: "metrics.endpoint") {
            OTelMetrics(endpoint: metricsEndpoint)
        } else if config.bool(forKey: "metrics", default: false) {
            OTelMetrics()
        } else {
            NodeConfig.default.metrics
        }

        let enableProfiling = config.bool(forKey: "enableProfiling", default: NodeConfig.default.enableProfiling)

        let feeRate = config.int(forKey: "feeRate") ?? NodeConfig.default.feeRate

        self.init(network: network, rpc: rpc, dataLocation: dataLocation, bind: bind, connect: connect, autoConnect: autoConnect, logLevel: logLevel, metrics: metrics, enableProfiling: enableProfiling, feeRate: feeRate)
    }
}

import _NIOFileSystem
import ArgumentParser

extension NodeConfig {
    static func loadConfiguration(_ configOptions: ConfigOptions) async throws(ValidationError) -> NodeConfig {
        let configPath: FilePath
        do {
            configPath = try await NodeConfig.checkLocation(configOptions.configPath)
        } catch {
            throw ValidationError(error)
        }

        let filePathJSON = configPath.appending("config.json")
        let fileProviderJSON: FileProvider<JSONSnapshot>
        do {
            fileProviderJSON = try await FileProvider<JSONSnapshot>(filePath: filePathJSON, allowMissing: true)
        } catch {
            throw ValidationError("Error opening/reading \(filePathJSON) file.\n\n\(error)")
        }

        let filePathSwift = configPath.appending("config.swift")
        let fileProviderSwift: FileProvider<SwiftSnapshot>
        do {
            fileProviderSwift = try await FileProvider<SwiftSnapshot>(filePath: filePathSwift, allowMissing: true)
        } catch {
            throw ValidationError("Error opening/reading \(filePathSwift) file.\n\n\(error)")
        }

        let config = ConfigReader(providers: [
            // First check command line arguments and environment variables.
            CommandLineArgumentsProvider(),
            EnvironmentVariablesProvider(),
            // Then check the config files for JSON and Swift.
            fileProviderJSON,
            fileProviderSwift,
            // Finally, use hardcoded defaults.
            InMemoryProvider(values: [:] /* No need for hardcoded values as NodeConfig handles defaults */)
        ])
        let nodeConfig: NodeConfig
        do {
            nodeConfig = try NodeConfig(config)
        } catch {
            throw ValidationError(error)
        }
        return nodeConfig
    }
}
