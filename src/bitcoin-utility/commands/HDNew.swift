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
        let seedHex = seed
        guard let seed = Data(hex: seed) else {
            throw ValidationError("Invalid hexadecimal value: seed")
        }
        let extendedKey: HDExtendedKey
        do {
            extendedKey = try HDExtendedKey(seed: seed)
        } catch {
            throw ValidationError("Invalid value: seed")
        }
        let result = extendedKey.serialized
        print(result)
    }
}
