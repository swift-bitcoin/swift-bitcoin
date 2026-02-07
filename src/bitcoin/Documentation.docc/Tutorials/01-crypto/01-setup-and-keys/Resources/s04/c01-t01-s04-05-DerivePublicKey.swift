import ArgumentParser
import Bitcoin

struct DerivePublicKey: ParsableCommand {

    @Argument var secretKey: String

    func run() throws(ValidationError) {
        guard let key = SecretKey(secretKey) else {
            throw ValidationError("Invalid secret key")
        }
        let pubkey = key.pubkey
        print("Public key: \(pubkey)")
    }
}
