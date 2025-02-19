import ArgumentParser
import JSONRPC
import BitcoinRPC

struct SendCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Sends an RPC command to a running Swift Bitcoin node."
    )

    @OptionGroup
    var parent: Node

    @Argument(help: "The JSON-RPC method name.")
    var method: String

    @Argument(help: "The JSON-RPC parameters.")
    var params: [String] = []

    mutating func run() async throws {
        if ([
            StartP2PCommand.self,
            ConnectCommand.self,
            DisconnectPeerCommand.self,
            StopP2PCommand.self,
            StopCommand.self,
            GenerateToAddressCommand.self
        ] as [RPCCommand.Type]).map({ $0.method}).contains(method) {
            // try StartP2P.parseAsRoot(params).run()
            throw ValidationError("Use bcutil node \(method) command instead.")
        }
        let params = JSONObject(RPCObject(params))
        try await launchRPCClient(host: parent.host, port: parent.resolvedPort, method: method, params: params)
    }
}
