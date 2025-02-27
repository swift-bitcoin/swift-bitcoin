import ArgumentParser
import JSONRPC

struct Help: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: HelpRPC.description
    )

    @OptionGroup var parent: Node

    @Argument(help: "An optional command. If omitted a summary of available commands will be returned.")
    var command: String?

    mutating func run() async throws {
        let request = JSONRPCRequest(.help(.init(command: command)))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
