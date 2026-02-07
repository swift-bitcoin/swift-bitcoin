import ArgumentParser
import Bitcoin

struct GenerateSecretKey: ParsableCommand {

    func run() throws {
        let key = SecretKey()
        print("Secret key: \(key)")
    }
}
