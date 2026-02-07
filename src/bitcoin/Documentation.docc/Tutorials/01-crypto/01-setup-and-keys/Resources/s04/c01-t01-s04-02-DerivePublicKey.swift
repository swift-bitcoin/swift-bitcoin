import ArgumentParser
import Bitcoin

struct DerivePublicKey: ParsableCommand {

    @Argument var secretKey: String

    func run() {
        // TODO: Derive the public key for the secret key argument
    }
}
