import ArgumentParser
import JSONRPC

struct GetPeerInfo: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GetPeerInfoRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.getPeerInfo))
    }
}
