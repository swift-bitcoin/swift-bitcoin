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
        guard let signature = SchnorrSignature(signature) else {
            throw ValidationError("Invalid Schnorr signature")
        }
        let result = signature.verify(message: message, pubkey: pubkey)
        print(result ? "Signature is valid" : "Signature is invalid")
    }
}
