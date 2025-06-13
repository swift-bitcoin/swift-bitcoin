import ArgumentParser
import BitcoinWallet
import BitcoinCrypto
import Foundation

/// Computes the public key corresponding to the provided secret key.
struct ECToPublic: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Computes the public key corresponding to the provided secret key."
    )

    @Argument(help: "The secret key in hex format.")
    var secretKey: String

    mutating func run() throws {
        guard let secretKeyData = Data(hex: secretKey) else {
            throw ValidationError("Invalid hexadecimal value: secretKey")
        }
        guard let secretKey = SecretKey(secretKeyData) else {
            throw ValidationError("Invalid secret key data: secretKey")
        }
        let result = PublicKey(secretKey).data.hex
        print(result)
        destroyECCSigningContext()
    }
}
