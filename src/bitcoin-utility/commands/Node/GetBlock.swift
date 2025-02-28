import ArgumentParser
import JSONRPC

struct GetBlock: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GetBlockRPC.description
    )

    @OptionGroup var parent: Node

    @Argument(help: "A block identifier.")
    var blockID: String

    mutating func run() async throws {
        let request = JSONRPCRequest(.getBlock(.init(blockID: blockID)))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
