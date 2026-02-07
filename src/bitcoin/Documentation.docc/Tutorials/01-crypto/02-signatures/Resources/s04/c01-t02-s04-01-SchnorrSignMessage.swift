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
        // TODO: Sign the message and output signature
    }
}
