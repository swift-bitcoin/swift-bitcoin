import ArgumentParser
import Bitcoin

struct SchnorrSignMessage: ParsableCommand {

    @Option var secretKey: String
    @Argument var message: String

    func run() throws(ValidationError) {
        guard let key = SecretKey(secretKey) else {
            throw ValidationError("Invalid secret key")
        }
        // TODO: Tweak key
        guard let signature = key.signSchnorr(message) else {
            throw ValidationError("Issue signing the message")
        }
        print("Schnorr signature: \(signature)")
    }
}
