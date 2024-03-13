import ArgumentParser
import JSONRPC
import Bitcoin

struct Connect: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Starts the P2P service."
    )

    @OptionGroup
    var parent: Node

    @Option(name: [.customShort("i"), .customLong("p2p-host")], help: "The address to bind the RPC server to.")
    var p2pHost = "0.0.0.0"

    @Option(name: [.customShort("q"), .customLong("p2p-port")], help: "The port for the P2P service to listen to. Default's to network's default port (\(NodeNetwork.main.defaultP2PPort) for \(NodeNetwork.main))")
    var p2pPort: Int?

    mutating func run() async throws {
        let p2pPort = p2pPort ?? parent.network.defaultP2PPort
        let params = JSONObject.list([
            .string(p2pHost),
            .integer(p2pPort)])
        try await launchRPCClient(host: parent.host, port: parent.resolvedPort, method: "connect", params: params)
    }
}
