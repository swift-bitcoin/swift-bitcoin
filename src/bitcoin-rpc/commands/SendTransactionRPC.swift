import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

extension SendTransactionRPC {

    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> Result {

        guard let txData = Data(hex: params.transactionData), let tx = try? Transaction(txData) else {
            throw .init(.invalidParams, "Transaction hex encoding or content invalid.")
        }

        do {
            try await blockchain.addTransaction(tx)
        } catch {
            throw .init(.invalidParams, "Transaction was not accepted into the mempool.")
        }

        return .init(mempoolSize: await blockchain.mempool.count)
    }
}
