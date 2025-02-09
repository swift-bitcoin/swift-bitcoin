import ArgumentParser
import BitcoinTransport

struct Node: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        subcommands: [SendRPC.self, StartP2P.self, Connect.self],
        defaultSubcommand: SendRPC.self)

    @Option(name: .shortAndLong, help: """
        The P2P network to connect to.
        
        During development this value will default to regtest.
    """)
    var network = NodeNetwork.regtest // TODO: Eventually switch to testnet4 and then mainnet.

    @Option(name: .shortAndLong, help: "The hostname or address of the RPC service to connect to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The server TCP port to connect to. Default's to network's default port (\(NodeNetwork.main.defaultRPCPort) for \(NodeNetwork.main))")
    var port: Int?

    var resolvedPort: Int {
        port ?? network.defaultRPCPort
    }
}
