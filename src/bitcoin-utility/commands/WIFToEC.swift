import ArgumentParser
import BitcoinWallet
import BitcoinCrypto
import Foundation

/// Converts a secret key in the Wallet Interchange Format (WIF) to hex raw format.
struct WIFToEC: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Converts a secret key in the Wallet Interchange Format (WIF) to hex raw format."
    )

    @Argument(help: "The secret key Wallet Interchange Format (WIF).")
    var secretKey: String

    mutating func run() throws {
        let secretKeyWIF = secretKey
        guard let secretKey = SecretKey(wif: secretKeyWIF) else {
            throw ValidationError("Invalid WIF-encoded secret key: secretKey")
        }
        print(secretKey.data.hex)
        destroyECCSigningContext()
    }
}
