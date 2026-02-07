import ArgumentParser
import Bitcoin
import Foundation

struct TweakPublicKey: ParsableCommand {

    @Option var tweak: String
    @Argument var publicKey: String

    func run() throws(ValidationError) {
        guard let pubkey = PublicKey(publicKey) else {
            throw ValidationError("Invalid public key")
        }
        guard let tweakData = tweak.data(using: .utf8) else {
            throw ValidationError("Could not encode tweak as UTF-8")
        }
        let tweakHash = Data(Hash256.hash(data: tweakData))
        // TODO: Apply the tweak and output result
    }
}
