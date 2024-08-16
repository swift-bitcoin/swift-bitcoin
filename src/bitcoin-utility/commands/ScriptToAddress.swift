import ArgumentParser
import BitcoinBase
import BitcoinWallet
import Foundation

/// Generates an address from a script..
struct ScriptToAddress: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Generates an address from a script."
    )

    @Option(name: .shortAndLong, help: "For tapscript a public key is required along with the script tree leaves.")
    var publicKey: String?

    @Option(name: .shortAndLong, help: "The signature version which determines the address type.")
    var sigVersion = SigVersion.base

    @Option(name: .shortAndLong, help: "The network for the address.")
    var network = WalletNetwork.main

    @Argument(help: "The script encoded as hexadecimal data. For tapscript include all script branches in breadth-first order.")
    var scripts: [String]

    mutating func run() throws {
        print(try Wallet.getAddress(scripts: scripts, publicKey: publicKey, sigVersion: sigVersion, network: network))
    }
}
