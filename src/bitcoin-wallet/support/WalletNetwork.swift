import Foundation

public enum WalletNetwork: String, CaseIterable, Sendable {
    case mainnet, testnet, regtest

    /// Bech32 human readable part (prefix).
    var bech32HRP: String {
        switch self {
        case .mainnet: "bc"
        case .testnet: "tb"
        case .regtest: "bcrt"
        }
    }
}
