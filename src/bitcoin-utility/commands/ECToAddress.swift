import ArgumentParser
import Bitcoin
import Foundation

/// Creates an address from the provided public key.
struct ECToAddress: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Creates an address from the provided public key."
    )

    @Option(name: .shortAndLong, help: "The signature version which determines the address type.")
    var sigVersion = SigVersion.base

    @Option(name: .shortAndLong, help: "The network for which the produced address will be valid..")
    var network = WalletNetwork.main

    @Argument(help: "A valid DER-encoded compressed/uncompressed public key in hex format.")
    var publicKey: String

    mutating func run() throws {
        print(try Wallet.getAddress(publicKey: publicKey, sigVersion: sigVersion, network: network))
    }
}
