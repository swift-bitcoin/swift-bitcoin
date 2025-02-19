import ArgumentParser
import JSONRPC
import BitcoinTransport
import BitcoinRPC

struct GenerateToAddress: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GenerateToAddressCommand.description
    )

    @OptionGroup
    var parent: Node

    @Argument(help: "The number of blocks to generate.")
    var blocks: Int

    @Argument(help: "The address to issue the block rewards to.")
    var address: String

    @Argument(help: "Maximum number of tries per block. Default: \(GenerateToAddressCommand.defaultMaxTries).")
    var maxTries: Int?

    mutating func run() async throws {
        let additionalParams: [JSONObject] = if let maxTries {[.integer(maxTries)]} else {[]}
        let params = JSONObject.list(
            [.integer(blocks), .string(address)] + additionalParams
        )
        try await launchRPCClient(host: parent.host, port: parent.resolvedPort, method: GenerateToAddressCommand.method, params: params)
    }
}
