import Foundation
import JSONRPC
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain

extension GetTransactionRPC {

    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> Result {

        guard let txID = TransactionIdentifier(displayHex: params.transactionID) else {
            throw .init(.invalidParams, "Transaction ID hex encoding or length is invalid.")
        }
        guard let tx = await blockchain.transaction(identifiedBy: txID) else {
            throw .init(.invalidParams, "Transaction not found.")
        }

        let ins = tx.ins.map {
            Result.Input(
                tx: $0.outpoint.txID.displayHex, // We display hashes in big endian
                output: $0.outpoint.out
            )
        }

        let outs = tx.outs.map {
            Result.Output(
                raw: $0.data.hex,
                amount: $0.value,
                script: $0.script.data.hex
            )
        }

        return .init(
            id: tx.idHex,
            witnessID: tx.witnessID.displayHex,
            inputs: ins,
            outputs: outs
        )
    }
}
