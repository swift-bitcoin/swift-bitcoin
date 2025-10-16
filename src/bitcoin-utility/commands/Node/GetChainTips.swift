import ArgumentParser
import JSONRPC

struct GetChainTips: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GetChainTipsRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.getChainTips))
    }
}
