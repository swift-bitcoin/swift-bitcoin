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
    var sig: String

    @Argument(help: "The message to verify.")
    var message: String

    mutating func run() throws {
        // Decode P2PKH address
        guard let address = LegacyAddress(address) else {
            throw ValidationError("Invalid P2PKH address: address")
        }
        guard let messageData = message.data(using: .utf8) else {
            throw ValidationError("Invalid UTF8-encoded message: message")
        }
        guard let sigData = Data(base64Encoded: sig) else {
            throw ValidationError("Invalid Base64-encoded signature: signature")
        }
        guard let sig = Signature(sigData, type: .recoverable) else {
            throw ValidationError("Invalid signature data: signature")
        }
        let result = if let pubkey = sig.recoverPubkey(messageData: messageData) {
            Data(Hash160.hash(data: pubkey.data)) == address.hash
        } else {
            false
        }
        print(result)
    }
}
