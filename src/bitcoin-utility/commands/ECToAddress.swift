import ArgumentParser
import BitcoinWallet
import BitcoinBase
import BitcoinCrypto
import Foundation

/// Creates an address from the provided public key.
struct ECToAddress: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Creates an address from the provided public key."
    )

    @Option(name: .shortAndLong, help: "The signature version which determines the address type.")
    var sigVersion = SigVersion.base

    @Option(name: .shortAndLong, help: "The network for which the produced address will be valid..")
    var network = WalletNetwork.main

    @Argument(help: "A valid DER-encoded compressed/uncompressed public key in hex format.")
    var pubkey: String

    mutating func run() throws {
        let pubkeyHex = pubkey
        guard let pubkeyData = Data(hex: pubkeyHex) else {
            throw ValidationError("Invalid hexadecimal value: pubkey")
        }
        guard let pubkey = PublicKey(pubkeyData) else {
            throw ValidationError("Invalid public key data: pubkey")
        }
        let result = switch sigVersion {
        case .base:
            LegacyAddress(pubkey, mainnet: network == .main).description
        case .witnessV0:
            SegwitAddress(pubkey, network: network).description
        case .witnessV1:
            TaprootAddress(pubkey, network: network).description
        }
        print(result)
    }
}
