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
        // TODO: Check hash length
        // TODO: Sign the hash instead of the message
        // guard let signature = key.sign(message) else {
        //     throw ValidationError("Problem signing the message")
        // }
        // print("ECDSA signature: \(signature)")
    }
}
