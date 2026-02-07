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
        // TODO: Parse signature
        // TODO: Get message as data
        // TODO: Recover public key and compare its hash against the hash received as argument
        // TODO: Output the result
    }
}
