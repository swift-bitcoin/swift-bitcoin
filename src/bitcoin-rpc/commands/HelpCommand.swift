import Foundation
import JSONRPC

/// Lists available RPC commands or shows the help menu for a specific command.
public struct HelpCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) {
        precondition(request.method == Self.method)
        self.request = request
        if
            case let .list(objects) = RPCObject(request.params),
            let first = objects.first,
            case let .string(command) = first,
            let command = commands.first(where: { $0.method == command }) {
            self.command = command
        } else {
            self.command = .none
        }
    }

    let request: JSONRequest
    let command: RPCCommand.Type?

    public func run() async -> JSONResponse {
        let result = if let command {
            """
            OVERVIEW: \(command.description)

            USAGE: \(command.method) \(command.params)
            """
        } else {
            """
            OVERVIEW: Help lists all available RPC commands with usage line.

            You can also pass it a method name to know more about that particular command.

            USAGE: bcutil node help
                   bcutil node help <rpc-command>

            RPC COMMANDS:

            \(commands.map { "    \($0.method)\($0.params.isEmpty ? "" : " \($0.params)") - \($0.description)" }.joined(separator: "\n"))

            See 'bcutil node help <subcommand>' for detailed help.
            """
        }
        return .init(id: request.id, result: JSONObject.string(result))
    }

    public static let method = "help"
    public static let params = "[command]"
    public static let description = "Lists available RPC commands or displays help for the specified command."
}

/// All available commands.
private let commands: [RPCCommand.Type] = [
    HelpCommand.self,
    StartP2PCommand.self,
    ConnectCommand.self,
    DisconnectPeerCommand.self,
    StopP2PCommand.self,
    StopCommand.self,
    GetStatusCommand.self,
    GetBlockchainInfoCommand.self,
    GetMempoolCommand.self,
    GetBlockCommand.self,
    GetBlockHashCommand.self,
    GetTransactionCommand.self,
    SendTransactionCommand.self,
    GenerateToAddressCommand.self,
    GenerateToPubkeyCommand.self,
    GetPeerInfoCommand.self
]
