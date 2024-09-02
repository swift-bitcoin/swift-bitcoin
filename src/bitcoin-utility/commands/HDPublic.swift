import ArgumentParser
import BitcoinWallet
import Foundation

/// Derives a child HD (BIP32) public key from another HD public key.
struct HDPublic: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Derives a child HD (BIP32) public key from another HD public key."
    )

    @Option(name: .shortAndLong, help: "The HD index.")
    var index = 0

    @Argument(help: "The parent HD public key.")
    var publicKey: String

    mutating func run() throws {
        let extendedKeySerialized = publicKey
        guard let extendedKey = try? ExtendedKey(extendedKeySerialized) else {
            throw ValidationError("Invalid extended private key format: extendedKey")
        }
        guard !extendedKey.hasSecretKey else {
            throw ValidationError("Invalid extended public key type: publicKey")
        }
        let result = extendedKey.derive(child: index).serialized
        print(result)
    }
}
