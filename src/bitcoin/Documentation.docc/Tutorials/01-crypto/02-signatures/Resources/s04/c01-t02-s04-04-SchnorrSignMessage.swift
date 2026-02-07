import ArgumentParser
import Bitcoin
import Foundation

struct SchnorrSignMessage: ParsableCommand {

    @Option var secretKey: String
    @Option var tweak: String?
    @Argument var message: String

    func run() throws(ValidationError) {
        guard let key = SecretKey(secretKey) else {
            throw ValidationError("Invalid secret key")
        }
        let tweakedKey: SecretKey
        if let tweak {
            guard let tweakData = tweak.data(using: .utf8) else {
                throw ValidationError("Could not encode tweak as UTF-8")
            }
            let tweakHash = Data(Hash256.hash(data: tweakData))
            tweakedKey = key.tweakXOnly(tweakHash)
        } else {
            tweakedKey = key
        }
        guard let signature = tweakedKey.signSchnorr(message) else {
            throw ValidationError("Issue signing the message")
        }
        print("Schnorr signature: \(signature)")
    }
}
