import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

extension GetTransactionRPC {

    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> Result {

        guard let txID = Data(hex: params.transactionID), txID.count == BitcoinTx.idLength else {
            throw .init(.invalidParams, "Transaction ID hex encoding or length is invalid.")
        }

        guard let tx = await blockchain.getTx(txID) else {
            throw .init(.invalidParams, "Transaction not found.")
        }

        let ins = tx.ins.map {
            Result.Input(
                tx: $0.outpoint.txID.hex,
                output: $0.outpoint.txOut
            )
        }

        let outs = tx.outs.map {
            Result.Output(
                raw: $0.binaryData.hex,
                amount: $0.value,
                script: $0.script.binaryData.hex
            )
        }

        return .init(
            id: tx.id.hex,
            witnessID: tx.witnessID.hex,
            inputs: ins,
            outputs: outs
        )
    }
}
