import ArgumentParser
import Bitcoin

struct HashMessage: ParsableCommand {

    @Argument var message: String

    func run() throws(ValidationError) {
        // TODO: Convert message to binary data
        // TODO: Hash the message data and display result
    }
}
