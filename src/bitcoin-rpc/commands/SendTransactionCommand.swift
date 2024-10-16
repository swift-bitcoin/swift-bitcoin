import Foundation
import BitcoinBase
import BitcoinTransport

public struct SendTransactionCommand: Sendable {

    public init(bitcoinNode: NodeService) {
        self.bitcoinNode = bitcoinNode
    }

    let bitcoinNode: NodeService

    public func run(_ request: JSONRequest) async throws {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(transactionHex) = first else {
            throw RPCError(.invalidParams("transaction"), description: "Transaction (hex string) is required.")
        }
        guard let transactionData = Data(hex: transactionHex), let transaction = BitcoinTransaction(transactionData) else {
            throw RPCError(.invalidParams("transaction"), description: "Transaction hex encoding or content invalid.")
        }
        do {
            try await bitcoinNode.addTransaction(transaction)
        } catch {
            throw RPCError(.invalidParams("transaction"), description: "Transaction was not accepted into the mempool.")
        }
    }

    public static let method = "send-transaction"
}
