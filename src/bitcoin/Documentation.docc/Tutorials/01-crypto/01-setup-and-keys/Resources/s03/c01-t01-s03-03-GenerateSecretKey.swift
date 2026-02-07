import ArgumentParser
import Bitcoin

struct GenerateSecretKey: ParsableCommand {

    func run() throws {
        let key = SecretKey()
        // TODO: Output the secret key
    }
}
