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

    @Option(name: .shortAndLong, help: "The network for which the produced address will be valid..")
    var network = WalletNetwork.main

    mutating func run() throws {
        let seedHex = seed
        guard let seed = Data(hex: seed) else {
            throw ValidationError("Invalid hexadecimal value: seed")
        }
        let extendedKey: HDExtendedKey
        do {
            extendedKey = try HDExtendedKey(seed: seed, mainnet: network == .main)
        } catch {
            throw ValidationError("Invalid value: seed")
        }
        let result = extendedKey.serialized
        print(result)
    }
}
