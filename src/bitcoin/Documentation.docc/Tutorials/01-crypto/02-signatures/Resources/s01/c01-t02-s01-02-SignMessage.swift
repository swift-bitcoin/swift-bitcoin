import ArgumentParser
import Bitcoin

struct SignMessage: ParsableCommand {

    @Option var secretKey: String
    @Argument var message: String

    func run() throws(ValidationError) {
        guard let key = SecretKey(secretKey) else {
            throw ValidationError("Invalid secret key")
        }
        guard let signature = key.sign(message) else {
            throw ValidationError("Problem signing the message")
        }
        print("ECDSA signature: \(signature)")
    }
}
