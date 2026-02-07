import ArgumentParser
import Bitcoin

struct SignMessageHash: ParsableCommand {

    @Option var secretKey: String
    @Argument var hash: String

    func run() throws(ValidationError) {
        guard let key = SecretKey(secretKey) else {
            throw ValidationError("Invalid secret key")
        }
        guard let hash = try? Base16Decoder().decode(hash) else {
            throw ValidationError("Invalid hexadecimal string")
        }
        guard hash.count == Hash256.Digest.byteCount else {
            throw ValidationError("Hash data must be \(Hash256.Digest.byteCount) bytes long")
        }
        // TODO: Sign the hash instead of the message
        // guard let signature = key.sign(message) else {
        //     throw ValidationError("Problem signing the message")
        // }
        // print("ECDSA signature: \(signature)")
    }
}
