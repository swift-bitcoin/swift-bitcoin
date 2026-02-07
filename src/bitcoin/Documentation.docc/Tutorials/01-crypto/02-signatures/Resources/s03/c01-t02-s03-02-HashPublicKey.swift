import ArgumentParser
import Bitcoin

struct HashPublicKey: ParsableCommand {

    @Argument var publicKey: String

    func run() throws(ValidationError) {
        guard let pubkey = PublicKey(publicKey) else {
            throw ValidationError("Invalid public key")
        }
        let hash = Hash160.hash(data: pubkey.data)
        print("Hash-160 Digest: \(hash)")
    }
}
