import ArgumentParser
import BitcoinWallet
import Foundation

/// Converts a BIP32 extended private key into its corresponding extended public key, also known as a neutered key.
struct HDToPublic: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Converts a BIP32 extended key into its corresponding extended public key, also known as a neutered key. For public keys the result will be the original key itself."
    )

    @Argument(help: "A serialized extended public/private key.")
    var extendedKey: String

    mutating func run() throws {
        let extendedKeySerialized = extendedKey
        guard let extendedKey = try? HDExtendedKey(extendedKeySerialized) else {
            throw ValidationError("Invalid extended key format: extendedKey")
        }
        let result = (extendedKey.hasSecretKey ? extendedKey.neutered : extendedKey).serialized
        print(result)
    }
}
