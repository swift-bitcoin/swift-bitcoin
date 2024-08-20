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
        print(try Wallet.wifToEC(secretKeyWIF: secretKey).secretKey.data.hex)
        destroyECCSigningContext()
    }
}
