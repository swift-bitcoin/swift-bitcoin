import ArgumentParser
import Bitcoin
import BitcoinCrypto
import Foundation

/// Generates a new secret key suitable for ECDSA signing.
struct ECNew: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Generates a new secret key suitable for ECDSA signing."
    )

    mutating func run() throws {
        print(Wallet.createSecretKey() as String)
        destroyECCSigningContext()
    }
}
