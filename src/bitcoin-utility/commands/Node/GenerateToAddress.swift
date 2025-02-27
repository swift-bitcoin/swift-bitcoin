import ArgumentParser
import BitcoinBlockchain
import JSONRPC

struct GenerateToAddress: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GenerateToAddressRPC.description
    )

    @OptionGroup var parent: Node

    @Argument(help: "The number of blocks to generate.")
    var blocks: Int

    @Argument(help: "The address to issue the block rewards to.")
    var address: String

    @Argument(help: "Maximum number of tries per block. Default: \(BlockchainService.Config.defaultMaxTries).")
    var maxTries: Int?

    mutating func run() async throws {
        let request = JSONRPCRequest(.generateToAddress(.init(blocks: blocks, address: address, maxTries: maxTries)))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
