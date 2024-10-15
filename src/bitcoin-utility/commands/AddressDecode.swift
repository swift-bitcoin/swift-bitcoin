import ArgumentParser
import BitcoinBase
import BitcoinWallet
import Foundation

/// Decodes a Bitcoin address into its basic components.
struct AddressDecode: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Decodes a Bitcoin address into its basic components."
    )

    @Option(name: .shortAndLong, help: "The signature version of the address.")
    var version = SigVersion.base

    @Argument(help: "The address to decode.")
    var address: String

    mutating func run() throws {
        let addressText = address
        guard let address = BitcoinAddress(addressText) else {
            throw ValidationError("Invalid address format: address")
        }
        print(AddressInfo(address))
    }
}

private struct AddressInfo: Codable, CustomStringConvertible {

    init(_ address: BitcoinAddress) {
        self.address = address.description
        mainnet = address.isMainnet
        script = address.isScript
        hash = address.hash.hex
    }

    let address: String
    let mainnet: Bool
    let script: Bool
    let hash: String

    var description: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let value = try! encoder.encode(self)
        return String(data: value, encoding: .utf8)!
    }
}
