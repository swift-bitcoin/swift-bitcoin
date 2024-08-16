import ArgumentParser
import BitcoinWallet
import Foundation

/// Converts a BIP32 extended private key into its corresponding extended public key, also known as a neutered key.
struct HDToPublic: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Converts a BIP32 extended private key into its corresponding extended public key, also known as a neutered key."
    )

    @Argument(help: "A serialized extended private key.")
    var privateKey: String

    mutating func run() throws {
        print(try Wallet.neuterHDPrivateKey(key: privateKey))
    }
}
