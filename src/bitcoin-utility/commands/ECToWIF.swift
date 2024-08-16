import ArgumentParser
import BitcoinWallet
import Foundation

/// Converts a raw private key to the Wallet Interchange Format (WIF).
struct ECToWIF: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Converts a raw private key to the Wallet Interchange Format (WIF)."
    )

    @Argument(help: "The secret key in raw hex format.")
    var secretKey: String

    @Option(name: .shortAndLong, help: "Whether the corresponding public key will be in compressed format.")
    var compressedPublicKey = true

    @Option(name: .shortAndLong, help: "The network for which the produced address will be valid..")
    var network = WalletNetwork.main

    mutating func run() throws {
        print(try Wallet.convertToWIF(secretKey: secretKey, compressedPublicKey: compressedPublicKey, network: network))
    }
}
