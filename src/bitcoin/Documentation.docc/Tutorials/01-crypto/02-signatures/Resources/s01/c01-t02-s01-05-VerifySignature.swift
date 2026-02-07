import ArgumentParser
import Bitcoin

struct VerifySignature: ParsableCommand {

    @Option var publicKey: String
    @Argument var signature: String
    @Argument var message: String

    func run() throws(ValidationError) {
        guard let pubkey = PublicKey(publicKey) else {
            throw ValidationError("Invalid public key")
        }
        guard let signature = ECDSASignature(signature) else {
            throw ValidationError("Invalid ECDSA signature")
        }
        // TODO: Verify signature
        // TODO: Output verification result
    }
}
