import ArgumentParser
import BitcoinWallet
import BitcoinCrypto
import Foundation

/// Generates a new secret key suitable for ECDSA signing.
struct ECNew: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Generates a new secret key suitable for ECDSA signing."
    )

    mutating func run() throws {
        let result = SecretKey().data.hex
        print(result)
        destroyECCSigningContext()
    }
}
