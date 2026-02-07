import ArgumentParser
import Foundation
import Bitcoin

struct RecoverableSignMessage: ParsableCommand {

    @Option var secretKey: String
    @Argument var message: String

    func run() throws(ValidationError) {
        guard let key = SecretKey(secretKey) else {
            throw ValidationError("Invalid secret key")
        }
        guard let messageData = message.data(using: .utf8) else {
            throw ValidationError("Message is not UTF-8 compatible")
        }
        // TODO: Sign the message data with the key. Use the recoverable public key method.
        // TODO: Output the result
    }
}
