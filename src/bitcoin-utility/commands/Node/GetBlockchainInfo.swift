import ArgumentParser
import JSONRPC

struct GetBlockchainInfo: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GetBlockchainInfoRPC.description
    )

    @OptionGroup var parent: Node

    mutating func run() async throws {
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(.getBlockchainInfo))
    }
}
