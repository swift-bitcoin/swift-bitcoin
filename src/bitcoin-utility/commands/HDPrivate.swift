import ArgumentParser
import BitcoinWallet
import Foundation

/// Derives a child HD (BIP32) private key from another HD private key.
struct HDPrivate: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Derives a child HD (BIP32) private key from another HD private key."
    )

    @Option(name: .shortAndLong, help: "The HD index.")
    var index = 0

    @Flag(name: .shortAndLong, help: "Signal to create a hardened key.")
    var harden = false

    @Argument(help: "The parent HD private key.")
    var privateKey: String

    mutating func run() throws {
        print(try Wallet.deriveHDKey(key: privateKey, index: index, harden: harden))
    }
}
