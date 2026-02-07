import ArgumentParser
import Bitcoin

struct DerivePublicKey: ParsableCommand {

    @Argument var secretKey: String

    func run() throws(ValidationError) {
        guard let key = SecretKey(secretKey) else {
            throw ValidationError("Invalid secret key")
        }
        // TODO: Derive the public key for the secret key argument
    }
}
