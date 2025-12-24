import ArgumentParser
import JSONRPC

struct ReindexCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "reindex",
        abstract: ReindexRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.reindex))
    }
}
