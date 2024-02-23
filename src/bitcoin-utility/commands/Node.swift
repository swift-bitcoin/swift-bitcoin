import ArgumentParser
import Bitcoin

struct Node: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
        subcommands: [SendRPC.self, StartP2P.self, Connect.self],
        defaultSubcommand: SendRPC.self)

    @Option(name: .shortAndLong, help: "The P2P network to connect to.")
    var network = NodeNetwork.main

    @Option(name: .shortAndLong, help: "The hostname or address of the RPC service to connect to.")
    var host = "127.0.0.1"

    @Option(name: .shortAndLong, help: "The server TCP port to connect to. Default's to network's default port (\(NodeNetwork.main.defaultRPCPort) for \(NodeNetwork.main))")
    var port: Int?

    var resolvedPort: Int {
        port ?? network.defaultRPCPort
    }
}
