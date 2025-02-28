import ArgumentParser
import JSONRPC

struct GetMempool: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GetMempoolRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.getMempool))
    }
}
