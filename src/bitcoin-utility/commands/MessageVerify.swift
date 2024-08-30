import ArgumentParser
import BitcoinWallet
import BitcoinCrypto
import Foundation

/// Verifies a message signatue using the specified Bitcoin address.
struct MessageVerify: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Verifies a message signatue using the specified Bitcoin address."
    )

    @Argument(help: "The Bitcoin address used to verify the signature.")
    var address: String

    @Argument(help: "The signature encoded in Base64 format.")
    var signature: String

    @Argument(help: "The message to verify.")
    var message: String

    mutating func run() throws {
        // Decode P2PKH address
        guard let address = BitcoinAddress(address) else {
            throw ValidationError("Invalid P2PKH address: address")
        }
        guard let messageData = message.data(using: .utf8) else {
            throw ValidationError("Invalid UTF8-encoded message: message")
        }
        guard let signatureData = Data(base64Encoded: signature) else {
            throw ValidationError("Invalid Base64-encoded signature: signature")
        }
        guard let signature = Signature(signatureData, type: .recoverable) else {
            throw ValidationError("Invalid signature data: signature")
        }
        let result = if let publicKey = signature.recoverPublicKey(messageData: messageData) {
            hash160(publicKey.data) == address.hash
        } else {
            false
        }
        print(result)
    }
}
