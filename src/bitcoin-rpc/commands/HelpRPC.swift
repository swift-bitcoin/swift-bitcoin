import Foundation
import JSONRPC

extension HelpRPC {

    public func run() async throws(JSONRPCResponse.Error) -> [String : String] {
        var result: [String : String]
        if let method = params.command, let command = commands.first(where: { $0.method == method }) {
            result = .init()
            result[method] = """
            OVERVIEW: \(command.description)

            USAGE: \(command.method) \(command.params)
            """
        } else {
            result = .init(uniqueKeysWithValues: commands.filter{ $0.method != HelpRPC.method }.map {(
                $0.method,
                "\($0.params.isEmpty ? "" : " \($0.params)") - \($0.description)"
            )})

            result["_\(HelpRPC.method)"] = """
            OVERVIEW: Help lists all available RPC commands with usage line.

            You can also pass it a method name to know more about that particular command.

            USAGE: bcutil node help
                   bcutil node help <rpc-command>

            RPC COMMANDS:

            See 'bcutil node help <subcommand>' for detailed help.
            """
        }
        return result
    }
}

/// All available commands.
private let commands: [any RPCCommand.Type] = [
    HelpRPC.self,
    StatusRPC.self,
    StopRPC.self,
    StartP2PRPC.self,
    StopP2PRPC.self,
    DisconnectPeerRPC.self,
    ConnectRPC.self,
    GetBlockHashRPC.self,
    GetBlockRPC.self,
    GenerateToAddressRPC.self,
    GetBlockchainInfoRPC.self,
    GetMempoolRPC.self,
    GetTransactionRPC.self,
    SendTransactionRPC.self,
    GetPeerInfoRPC.self
]
