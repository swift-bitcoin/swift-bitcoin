import ArgumentParser
import JSONRPC
import BitcoinTransport
import BitcoinRPC

struct StopP2P: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: StopP2PCommand.method,
        abstract: StopP2PCommand.description
    )

    @OptionGroup
    var parent: Node

    mutating func run() async throws {
        let params = JSONObject.none
        try await launchRPCClient(host: parent.host, port: parent.resolvedPort, method: StopP2PCommand.method, params: params)
    }
}
