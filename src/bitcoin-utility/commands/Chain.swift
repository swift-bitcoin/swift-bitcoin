import ArgumentParser
import Foundation
import enum BitcoinTransport.NodeNetwork

struct Chain: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "",
        discussion: """
        Access local chain data.
        """,
        subcommands: [
            ChainInfo.self, ChainTips.self, Reindex.self
        ]
    )

    @Option(name: .shortAndLong, help: "The P2P network for the data directory.")
    var network = Network.mainnet

    @Option(name: .long, help: "The optional signet challenge as hex string.")
    var signetChallenge: String?

    var resolvedNetwork: NodeNetwork {
        get throws(ValidationError) {
            let challenge: [UInt8]?
            if let signetChallenge {
                guard let parsedChallenge = Data(hex: signetChallenge) else {
                    throw ValidationError("Invalid hexadecimal value: signet-challenge")
                }
                challenge = [UInt8](parsedChallenge)
            } else {
                challenge = nil
            }
            return switch network {
            case .mainnet: .mainnet
            case .testnet: .testnet
            case .regtest: .regtest
            case .signet: .signet(challenge: challenge)
            }
        }
    }
}

enum Network: String, ExpressibleByArgument {
    case mainnet, testnet, regtest, signet
}
