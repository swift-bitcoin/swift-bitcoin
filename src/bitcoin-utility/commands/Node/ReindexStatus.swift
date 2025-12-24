import ArgumentParser
import JSONRPC

struct ReindexStatus: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ReindexStatusRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.reindexStatus))
    }
}
