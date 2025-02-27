/// Lists available RPC commands or shows the help menu for a specific command.
public struct HelpRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {

        public init(command: String?) {
            self.command = command
        }

        public let command: String?
    }

    public typealias Result = [String : String]

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "help"
    public static let params = "[<command>]"
    public static let description = "Lists available RPC commands or displays help for the specified command."
}
