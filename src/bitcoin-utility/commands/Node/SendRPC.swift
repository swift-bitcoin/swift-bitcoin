import ArgumentParser
import BitcoinRPC

struct SendRPC: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Connect to a running server."
    )

    @OptionGroup
    var parent: Node

    @Argument(help: "The JSON-RPC method name.")
    var method: String

    @Argument(help: "The JSON-RPC parameters.")
    var params: [String] = []

    mutating func run() async throws {
        if method == "start-p2p" || method == "connect" {
            // try StartP2P.parseAsRoot(params).run()
            throw ValidationError("Use bcutil node \(method) command instead.")
        }
        let params = if method == "generate-to" {
            JSONObject(RPCObject(params))
        } else {
            JSONObject(RPCObject(params.compactMap { Int($0) }))
        }
        try await launchRPCClient(host: parent.host, port: parent.resolvedPort, method: method, params: params)
    }
}
