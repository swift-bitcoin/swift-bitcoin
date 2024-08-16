import ArgumentParser
import BitcoinWallet
import Foundation

/// Generates a new HD wallet master key from seed.
struct HDNew: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Generates a new HD wallet master key from seed."
    )

    @Argument(help: "The entropy in hexadecimal format.")
    var seed: String

    mutating func run() throws {
        print(try Wallet.computeHDMasterKey(seed))
    }
}
