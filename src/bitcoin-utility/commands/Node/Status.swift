import ArgumentParser
import JSONRPC

struct Status: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: StatusRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.status))
    }
}
