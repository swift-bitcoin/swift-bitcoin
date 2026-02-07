import ArgumentParser
import Bitcoin

struct VerifySchnorrSignature: ParsableCommand {

    @Option var publicKey: String
    @Argument var signature: String
    @Argument var message: String

    func run() throws(ValidationError) {
        guard let pubkey = PublicKey(publicKey) else {
            throw ValidationError("Invalid public key")
        }
        // TODO: Parse Schnorr signature
        // TODO: Verify Schnorr signature with public key
        // TODO: Output result
    }
}
