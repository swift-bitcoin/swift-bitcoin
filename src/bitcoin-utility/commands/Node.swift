import ArgumentParser

struct Node: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Connect to a running server."
    )

    @Option(name: .shortAndLong, help: "The hostname or address of the RPC service to connect to.")
    var host = "127.0.0.1"

    @Option(name: .shortAndLong, help: "The server TCP port to connect to.")
    var port = 18332

    @Argument(help: "The JSON-RPC method name.")
    var method: String

    @Argument(help: "The JSON-RPC parameters.")
    var params: [String] = []

    mutating func run() async throws {
        try await launchRPCClient(host: host, port: port, method: method, params: params)
    }
}
