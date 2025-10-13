import Foundation
import ArgumentParser
import JSONRPC

struct DisconnectPeer: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: DisconnectPeerRPC.description
    )

    @OptionGroup var parent: Node

    @Argument(help: "The ID of the peer to disconnect.")
    var peerID: Int

    mutating func run() async throws {
        let request = JSONRPCRequest(.disconnectPeer(.init(peerID: peerID)))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
