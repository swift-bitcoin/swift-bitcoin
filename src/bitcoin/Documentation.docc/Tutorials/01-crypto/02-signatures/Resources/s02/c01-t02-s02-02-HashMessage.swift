import ArgumentParser
import Bitcoin

struct HashMessage: ParsableCommand {

    @Argument var message: String

    func run() throws(ValidationError) {
        guard let messageData = message.data(using: .utf8) else {
            throw ValidationError("Could not encode message as UTF-8")
        }
        // TODO: Hash the message data and display result
    }
}
