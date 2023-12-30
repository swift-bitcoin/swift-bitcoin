import ArgumentParser
import Bitcoin
import Foundation

/// Computes the public key corresponding to the provided secret key.
struct ECToPublic: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Computes the public key corresponding to the provided secret key."
    )

    @Argument(help: "The secret key in hex format.")
    var secretKey: String

    mutating func run() throws {
        print(try Wallet.getPublicKey(secretKey: secretKey))
    }
}
