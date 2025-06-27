import BitcoinTransport

extension NodeNetwork {
    init(_ network: NodeConfig.Network) {
        self.init(rawValue: network.rawValue)!
    }
}
