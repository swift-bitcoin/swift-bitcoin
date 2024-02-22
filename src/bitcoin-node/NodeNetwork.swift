import ArgumentParser

enum NodeNetwork: String, ExpressibleByArgument {
    case main, test, signet, regtest

    var defaultRPCPort: Int {
        switch self {
        case .main: 8332
        case .test: 18332
        case .signet: 38332
        case .regtest: 18443
        }
    }

    var defaultP2PPort: Int {
        switch self {
        case .main: 8333
        case .test: 18333
        case .signet: 38333
        case .regtest: 18444
        }
    }
}
