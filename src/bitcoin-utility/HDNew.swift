import ArgumentParser
import Bitcoin
import Foundation

/// New HD wallet master key from seed.
struct HDNew: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "New HD wallet master key from seed."
    )

    @Argument(help: "Entropy in hexadecimal format.")
    var seed: String

    mutating func run() throws {
        print(try Wallet.computeHDMasterKey(seed))
    }
}
