import ArgumentParser
import JSONRPC
import BitcoinTransport
import BitcoinRPC

struct Stop: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: StopCommand.method,
        abstract: StopCommand.description
    )

    @OptionGroup
    var parent: Node

    mutating func run() async throws {
        let params = JSONObject.none
        try await launchRPCClient(host: parent.host, port: parent.resolvedPort, method: StopCommand.method, params: params)
    }
}
