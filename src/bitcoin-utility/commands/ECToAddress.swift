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
    var publicKey: String

    mutating func run() throws {
        let publicKeyHex = publicKey
        guard let publicKeyData = Data(hex: publicKeyHex) else {
            throw ValidationError("Invalid hexadecimal value: publicKey")
        }
        guard let publicKey = PublicKey(publicKeyData) else {
            throw ValidationError("Invalid public key data: publicKey")
        }
        let result = switch sigVersion {
        case .base:
            BitcoinAddress(publicKey, network: network).description
        case .witnessV0:
            SegwitAddress(publicKey, network: network).description
        case .witnessV1:
            TaprootAddress(publicKey, network: network).description
        }
        print(result)
    }
}
