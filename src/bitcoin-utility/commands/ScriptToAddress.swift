import ArgumentParser
import BitcoinBase
import BitcoinCrypto
import BitcoinWallet
import Foundation

/// Generates an address from a script..
struct ScriptToAddress: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Generates an address from a script."
    )

    @Option(name: .shortAndLong, help: "For tapscript an EC public key in compressed format is required along with the script tree leaves.")
    var pubkey: String?

    @Option(name: .shortAndLong, help: "The signature version which determines the address type.")
    var sigVersion = SigVersion.base

    @Option(name: .shortAndLong, help: "The network for the address.")
    var network = WalletNetwork.main

    @Argument(help: "The script encoded as hexadecimal data. For tapscript include all script branches in breadth-first order.")
    var scripts: [String]

    mutating func run() throws {
        let scriptsHex = scripts
        guard scriptsHex.count > 0 else {
            throw ValidationError("A script is needed for all sig version: scripts")
        }
        let scriptsData = scripts.compactMap { Data(hex: $0) }
        guard scriptsData.count == scriptsHex.count else {
            throw ValidationError("Invalid hexadecimal value: scripts")
        }
        let scripts = scriptsData.compactMap { try? Script($0) }
        guard scripts.count == scriptsHex.count else {
            throw ValidationError("Invalid hexadecimal value: scripts")
        }
        let result: String
        switch sigVersion {
        case .base:
            let address = LegacyAddress(scripts[0], mainnet: network == .main)
            result = address.description
        case .witnessV0:
            let address = SegwitAddress(scripts[0], network: network)
            result = address.description
        case .witnessV1:
            guard let pubkeyHex = pubkey else {
                throw ValidationError("Public key is required for witness V1: pubkey")
            }
            guard let pubkeyData = Data(hex: pubkeyHex) else {
                throw ValidationError("Invalid hexadecimal value: pubkey")
            }
            guard let pubkey = PublicKey(compressed: pubkeyData) else {
                throw ValidationError("Invalid compressed public key data: pubkey")
            }
            let address = TaprootAddress(pubkey, scripts: scripts, network: network)
            result = address.description
        }
        print(result)
    }
}
