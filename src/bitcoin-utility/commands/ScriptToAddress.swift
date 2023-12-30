import ArgumentParser
import Bitcoin
import Foundation

/// Generates an address from a script..
struct ScriptToAddress: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Generates an address from a script."
    )

    @Option(name: .shortAndLong, help: "The network for the address.")
    var network = WalletNetwork.main

    @Argument(help: "The script encoded as hexadecimal data.")
    var script: String

    mutating func run() throws {
        print(try Wallet.getAddress(script: script, network: network))
    }
}
