import ArgumentParser
import JSONRPC

struct StopP2P: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: StopP2PRPC.method,
        abstract: StopP2PRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.stopP2P))
    }
}
