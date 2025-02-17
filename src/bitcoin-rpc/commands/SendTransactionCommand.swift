import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Submits a new (raw) transaction to the mempool. The transaction needs to be both valid and signed for it to be accepted.
public struct SendTransactionCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)
        self.request = request

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(txHex) = first else {
            throw .init(.invalidParams("transaction"), description: "Transaction (hex string) is required.")
        }
        guard let txData = Data(hex: txHex), let tx = try? BitcoinTx(binaryData: txData) else {
            throw .init(.invalidParams("transaction"), description: "Transaction hex encoding or content invalid.")
        }
        self.tx = tx
    }

    let request: JSONRequest
    let tx: BitcoinTx

    /// Request must contain single transaction (string) parameter.
    public func run(blockchain: BlockchainService) async throws(RPCError) {

        do {
            try await blockchain.addTx(tx)
        } catch {
            throw .init(.invalidParams("transaction"), description: "Transaction was not accepted into the mempool.")
        }
    }

    public static let method = "send-transaction"
    public static let params = "<raw-transaction>"
    public static let description = "Submits the specified transaction to the node."
}
