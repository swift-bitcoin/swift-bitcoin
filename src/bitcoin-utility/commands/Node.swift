import ArgumentParser

struct Node: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Connect to a running server."
    )

    @Option(name: .shortAndLong, help: "The server TCP port to connect to.")
    var port = 8333

    @Argument(help: "The JSON-RPC method name.")
    var method: String

    @Argument(help: "The JSON-RPC parameters.")
    var params: [String] = []

    mutating func run() async throws {
        try await launchRPCClient(port: port, method: method, params: params)
    }
}
