import ArgumentParser
import JSONRPC
import BitcoinTransport // NodeNetwork

struct Connect: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ConnectRPC.description
    )

    @OptionGroup var parent: Node

    @Option(name: [.customShort("i"), .customLong("peer-host")], help: "The address to bind the RPC server to.")
    var peerHost = "0.0.0.0"

    @Option(name: [.customShort("q"), .customLong("peer-port")], help: "The port for the P2P service to listen to. Default's to network's default port (\(NodeNetwork.mainnet.defaultP2PPort) for \(NodeNetwork.mainnet))")
    var peerPort: Int?

    mutating func run() async throws {
        let network = try parent.resolvedNetwork
        let request = JSONRPCRequest(.connect(.init(
            host: peerHost,
            port: peerPort ?? network.defaultP2PPort
        )))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
