import ArgumentParser
import enum BitcoinTransport.NodeNetwork

struct Node: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Connects to a runing node and sends it an RPC command.",
        discussion: """
        Use one of the subcommands to specify which RPC method to call.
        """,
        subcommands: [
            Help.self,
            Status.self,
            Stop.self,
            StartP2P.self,
            StopP2P.self,
            Connect.self,
            DisconnectPeer.self,
            GetBlockHash.self,
            GetBlock.self,
            GetHeader.self,
            GenerateToAddress.self,
            GetBlockchainInfo.self,
            GetChainTips.self,
            GetMempool.self,
            GetPeerInfo.self,
            GetTransaction.self,
            SendTransaction.self,
            SendCommand.self,
            ReindexCommand.self,
            ReindexStatus.self,
            ReindexStop.self
        ],
        defaultSubcommand: SendCommand.self
    )

    @Option(name: .shortAndLong, help: "The P2P network to connect to. During development this value will default to regtest.")
    var network = NodeNetwork.testnet // TODO: Eventually switch to testnet4 and then mainnet.

    @Option(name: .shortAndLong, help: "The hostname or address of the RPC service to connect to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The server TCP port to connect to. Default's to network's default port (\(NodeNetwork.testnet.defaultRPCPort) for \(NodeNetwork.testnet))")
    var port: Int?

    var resolvedPort: Int {
        port ?? network.defaultRPCPort
    }
}
