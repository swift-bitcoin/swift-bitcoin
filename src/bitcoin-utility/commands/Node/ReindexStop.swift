import ArgumentParser
import JSONRPC

struct ReindexStop: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ReindexStopRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.reindexStop))
    }
}
