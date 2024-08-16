import ArgumentParser
import BitcoinBlockchain

struct Start: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Launch a Bitcoin node instance."
    )

    @Option(name: .shortAndLong, help: "The P2P network to connect to.")
    var network = NodeNetwork.main

    @Option(name: .shortAndLong, help: "The address to bind the RPC server to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeNetwork.main.defaultRPCPort) for \(NodeNetwork.main))")
    var port: Int?

    mutating func run() async throws {
        let port = port ?? network.defaultRPCPort
        try await launchNode(host: host, port: port)
    }
}
