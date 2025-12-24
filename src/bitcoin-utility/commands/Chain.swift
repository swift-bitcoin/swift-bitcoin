import ArgumentParser
import enum BitcoinTransport.NodeNetwork

struct Chain: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "",
        discussion: """
        Access local chain data.
        """,
        subcommands: [
            ChainInfo.self, Reindex.self
        ]
    )

    @Option(name: .shortAndLong, help: "The P2P network for the data directory. During development this value will default to regtest.")
    var network = NodeNetwork.testnet // TODO: Eventually switch to testnet4 and then mainnet.
}
