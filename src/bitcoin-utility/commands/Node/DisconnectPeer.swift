import ArgumentParser
import JSONRPC
import BitcoinTransport
import BitcoinRPC

struct DisconnectPeer: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: DisconnectPeerCommand.description
    )

    @OptionGroup
    var parent: Node

    @Argument(help: "The ID of the peer to disconnect.")
    var peerID: String

    mutating func run() async throws {
        let params = JSONObject.list([.string(peerID)])
        try await launchRPCClient(host: parent.host, port: parent.resolvedPort, method: DisconnectPeerCommand.method, params: params)
    }
}
