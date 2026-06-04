extension NodeConfig: Decodable {
    // This extension does not need to be in NodeConfig when used from a Swift script

    init(from decoder: any Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.network = try container.decodeIfPresent(NodeConfig.Network.self, forKey: .network) ?? defaults.network

        self.rpc = try container.decodeIfPresent(NodeConfig.RPCSettings.self, forKey: .rpc) ?? defaults.rpc

        self.dataLocation = try container.decodeIfPresent(NodeConfig.DataLocation.self, forKey: .dataLocation) ?? defaults.dataLocation

        self.bind = if let b = try container.decodeIfPresent(BindSettings.self, forKey: .bind) {
            b
        } else if let bindString = try container.decodeIfPresent(String.self, forKey: .bind), let b = BindSettings(bindString) {
            b
        } else {
            defaults.bind
        }

        self.connect = if let c = try container.decodeIfPresent([RemotePeer].self, forKey: .connect) {
            c
        } else if let connectStrings = try container.decodeIfPresent([String].self, forKey: .connect) {
            connectStrings.compactMap(RemotePeer.init)
        } else {
            defaults.connect
        }

        self.autoConnect = try container.decodeIfPresent(Bool.self, forKey: .autoConnect) ?? defaults.autoConnect
        self.logLevel = try container.decodeIfPresent(LogLevel.self, forKey: .logLevel) ?? defaults.logLevel
        self.metrics = try container.decodeIfPresent(NodeConfig.OTelMetrics.self, forKey: .metrics) ?? defaults.metrics
        self.enableProfiling = try container.decodeIfPresent(Bool.self, forKey: .enableProfiling) ?? defaults.enableProfiling
        self.feeRate = try container.decodeIfPresent(Int.self, forKey: .feeRate) ?? defaults.feeRate
    }
}

extension NodeConfig.DataLocation: Decodable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let other = Self(value) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid Location format: \(value)")
            )
        }
        self = other
    }

    init?(_ value: String) {
        switch value {
        case "in-memory":
            self = .inMemory
        case "default-path":
            self = .defaultPath
        default:
            let regex = #/custom\((.+)\)/# // Because this file is run as a Swift script we cannot use bare regex `/custom\((.+)\)/`
            guard let match = try? regex.wholeMatch(in: value) else {
                return nil
            }
            let customPathSubstring = match.1  // Substring
            let customPath = String(customPathSubstring)
            self = .custom(path: customPath)
        }
    }
}

import BitcoinTransport

extension NodeConfig.BindSettings {

    init?(_ bind: String) {
        if let (host, port) = IPv4Address.parse(bind) {
            self.init(host: host, port: port)
        } else if let (host, port) = IPv6Address.parse(bind) {
            self.init(host: host, port: port)
        } else {
            return nil
        }
    }
}

extension NodeConfig.RemotePeer {

    init?(_ bind: String) {
        if let (host, port) = IPv4Address.parse(bind) {
            self.init(host: host, port: port)
        } else if let (host, port) = IPv6Address.parse(bind) {
            self.init(host: host, port: port)
        } else {
            return nil
        }
    }
}
