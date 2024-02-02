import ArgumentParser
import Bitcoin
import BitcoinCrypto
import Foundation

/// Converts a secret key in the Wallet Interchange Format (WIF) to hex raw format.
struct WIFToEC: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Converts a secret key in the Wallet Interchange Format (WIF) to hex raw format."
    )

    @Argument(help: "The secret key Wallet Interchange Format (WIF).")
    var secretKey: String

    mutating func run() throws {
        print(try Wallet.wifToEC(secretKey: secretKey).secretKey.hex)
        destroyECCSigningContext()
    }
}
