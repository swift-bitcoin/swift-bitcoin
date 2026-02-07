import ArgumentParser
import Bitcoin

struct HashPublicKey: ParsableCommand {

    @Argument var publicKey: String

    func run() throws(ValidationError) {
        guard let pubkey = PublicKey(publicKey) else {
            throw ValidationError("Invalid public key")
        }
        // TODO: Hash the public key using the Hash-160 algorithm
    }
}
