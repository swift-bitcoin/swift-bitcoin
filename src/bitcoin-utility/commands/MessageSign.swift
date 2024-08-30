import ArgumentParser
import BitcoinWallet
import BitcoinCrypto
import Foundation

/// Signs a message with a private key. The signature is encoded in Base64 format.
struct MessageSign: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Signs a message with a private key.The signature is encoded in Base64 format."
    )

    @Argument(help: "The secret key in WIF format.")
    var secretKey: String

    @Argument(help: "The message to sign.")
    var message: String

    mutating func run() throws {
        let secretKeyWIF = secretKey
        var metadataOptional = SecretKey.WIFMetadata?.none
        guard let secretKey = SecretKey(wif: secretKeyWIF, metadata: &metadataOptional) else {
            throw ValidationError("Invalid WIF-encoded secret key: secretKey")
        }
        guard let metadata = metadataOptional else {
            fatalError("Could not obtain WIF metadata")
        }
        guard let messageData = message.data(using: .utf8) else {
            throw ValidationError("Invalid UTF8-encoded message: message")
        }
        let signature = Signature(messageData: messageData, secretKey: secretKey, type: .recoverable, recoverCompressedKeys: metadata.compressedPublicKeys)
        let result = signature.base64
        print(result)
        destroyECCSigningContext()
    }
}
