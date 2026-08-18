import Foundation

public enum WalletNetwork: String, CaseIterable, Sendable {
    case mainnet, /* testnet3, */ testnet, regtest, signet

    /// Bech32 human readable part (prefix).
    var bech32HRP: String {
        switch self {
        case .mainnet: "bc"
        case .testnet, .signet: "tb"
        case .regtest: "bcrt"
        }
    }
}
