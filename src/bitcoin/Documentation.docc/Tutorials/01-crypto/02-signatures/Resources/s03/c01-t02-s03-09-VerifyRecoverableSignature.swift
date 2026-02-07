import Foundation
import ArgumentParser
import Bitcoin

struct VerifyRecoverableSignature: ParsableCommand {

    @Option var publicKeyHash: String
    @Argument var signature: String
    @Argument var message: String

    func run() throws(ValidationError) {
        guard let hash = try? Base16Decoder().decode(publicKeyHash) else {
            throw ValidationError("Invalid hexadecimal string")
        }
        guard hash.count == Hash160.Digest.byteCount else {
            throw ValidationError("Hash data must be \(Hash160.Digest.byteCount) bytes long")
        }
        guard let signature = RecoverableSignature(signature) else {
            throw ValidationError("Invalid signature data")
        }
        guard let messageData = message.data(using: .utf8) else {
            throw ValidationError("Message is not UTF-8 compatible")
        }
        // TODO: Recover public key and compare its hash against the hash received as argument
        // TODO: Output the result
    }
}
