import ArgumentParser
import JSONRPC

struct GetTransaction: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: GetTransactionRPC.description
    )

    @OptionGroup var parent: Node

    @Argument(help: "A transaction identifier.")
    var transactionID: String

    mutating func run() async throws {
        let request = JSONRPCRequest(.getTransaction(.init(transactionID: transactionID)))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
