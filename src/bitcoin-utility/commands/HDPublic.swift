import ArgumentParser
import Bitcoin
import Foundation

/// Derives a child HD (BIP32) public key from another HD public key.
struct HDPublic: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Derives a child HD (BIP32) public key from another HD public key."
    )

    @Option(name: .shortAndLong, help: "The HD index.")
    var index = 0

    @Flag(name: .shortAndLong, help: "Signal to create a hardened key.")
    var harden = false

    @Argument(help: "The parent HD public key.")
    var publicKey: String

    mutating func run() throws {
        print(try Wallet.deriveHDKey(isPrivate: false, key: publicKey, index: index, harden: harden))
    }
}
