import ArgumentParser
import BitcoinBase
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
            let challenge: Script?
            if let signetChallenge {
                guard let parsedChallenge = Data(hex: signetChallenge) else {
                    throw ValidationError("Invalid hexadecimal value: signet-challenge")
                }
                do {
                    challenge = try Script(parsedChallenge)
                } catch {
                    throw ValidationError("Invalid script signet-challenge.")
                }
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
