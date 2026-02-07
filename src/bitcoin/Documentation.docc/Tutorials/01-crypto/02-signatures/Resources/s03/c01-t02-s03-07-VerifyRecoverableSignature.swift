import Foundation
import ArgumentParser
import Bitcoin

struct VerifyRecoverableSignature: ParsableCommand {

    @Option var publicKeyHash: String
    @Argument var signature: String
    @Argument var message: String

    func run() throws(ValidationError) {
        // TODO: Parse and validate public key hash
        // TODO: Parse signature
        // TODO: Get message as data
        // TODO: Recover public key and compare its hash against the hash received as argument
        // TODO: Output the result
    }
}
