import ArgumentParser
import JSONRPC

struct GetBlockHash: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GetBlockHashRPC.description
    )

    @OptionGroup var parent: Node

    @Argument(help: "A block height.")
    var height: Int

    mutating func run() async throws {
        let request = JSONRPCRequest(.getBlockHash(.init(height: height)))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
