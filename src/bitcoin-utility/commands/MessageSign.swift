import ArgumentParser
import BitcoinWallet
import BitcoinCrypto
import Foundation

/// Signs a message with a private key. The signature is encoded in Base64 format.
struct MessageSign: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Signs a message with a private key.The signature is encoded in Base64 format."
    )

    @Argument(help: "The secret key in raw hex format.")
    var secretKey: String

    @Argument(help: "The message to sign.")
    var message: String

    mutating func run() throws {
        print(try Wallet.sign(secretKey: secretKey, message: message))
        destroyECCSigningContext()
    }
}
