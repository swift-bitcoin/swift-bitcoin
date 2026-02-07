import ArgumentParser
import Bitcoin

struct TweakPublicKey: ParsableCommand {

    @Option var tweak: String
    @Argument var publicKey: String

    func run() throws(ValidationError) {
        guard let pubkey = PublicKey(publicKey) else {
            throw ValidationError("Invalid public key")
        }
        // TODO: Get tweak as UTF8 data
        // TODO: Hash the tweak data
        // TODO: Apply the tweak and output result
    }
}
