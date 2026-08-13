import ArgumentParser
import JSONRPC
import BitcoinTransport // NodeNetwork

struct StartP2P: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: StartP2PRPC.method,
        abstract: StartP2PRPC.description
    )

    @OptionGroup var parent: Node

    @Option(name: [.customShort("i"), .customLong("p2p-host")], help: "The address to bind the RPC server to.")
    var p2pHost = "0.0.0.0"

    @Option(name: [.customShort("q"), .customLong("p2p-port")], help: "The port for the P2P service to listen to. Default's to network's default port (\(NodeNetwork.mainnet.defaultP2PPort) for \(NodeNetwork.mainnet))")
    var p2pPort: Int?

    mutating func run() async throws {
        let network = try parent.resolvedNetwork
        let request = JSONRPCRequest(.startP2P(.init(
            host: p2pHost,
            port: p2pPort ?? network.defaultP2PPort
        )))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
