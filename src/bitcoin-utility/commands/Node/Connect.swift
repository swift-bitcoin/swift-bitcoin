import ArgumentParser
import JSONRPC

struct Connect: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ConnectRPC.description
    )

    @OptionGroup var parent: Node

    @Option(name: [.customShort("i"), .customLong("peer-host")], help: "The address to bind the RPC server to.")
    var peerHost = "localhost"

    @Option(name: [.customShort("q"), .customLong("peer-port")], help: "The port for the P2P service to listen to. Defaults: mainnet=8333, testnet=48333, regtest=18444, signet=38333")
    var peerPort: Int?

    mutating func run() async throws {
        let request = JSONRPCRequest(.connect(.init(
            host: peerHost,
            port: peerPort
        )))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
