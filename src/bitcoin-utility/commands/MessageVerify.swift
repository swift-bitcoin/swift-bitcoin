import ArgumentParser
import Bitcoin
import Foundation

/// Verifies a message signatue using the specified Bitcoin address.
struct MessageVerify: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Verifies a message signatue using the specified Bitcoin address."
    )

    @Argument(help: "The Bitcoin address used to verify the signature.")
    var address: String

    @Argument(help: "The signature encoded in Base64 format.")
    var signature: String

    @Argument(help: "The message to verify.")
    var message: String

    mutating func run() throws {
        print(try Wallet.verify(address: address, signature: signature, message: message))
    }
}
