import ArgumentParser
import JSONRPC

struct SendTransaction: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: SendTransactionRPC.description
    )

    @OptionGroup var parent: Node

    @Argument(help: "Hex-encoded transaction data.")
    var transactionData: String

    mutating func run() async throws {
        let request = JSONRPCRequest(.sendTransaction(.init(transactionData: transactionData)))
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: request)
    }
}
