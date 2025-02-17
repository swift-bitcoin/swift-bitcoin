import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Transaction information including ID, witness ID, inputs and outputs. For each output a raw value is also included in order to facilitate the signing of transactions which require the serialization of previous outputs.
public struct GetTransactionCommand: RPCCommand, Sendable {

    internal struct Output: JSONStringConvertible {

        struct Input: Encodable {
            let tx: String
            let output: Int
        }

        struct Output: Encodable {
            let raw: String
            let amount: SatoshiAmount
            let script: String
        }

        let id: String
        let witnessID: String
        let inputs: [Input]
        let outputs: [Output]
    }

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)
        self.request = request

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(txIDHex) = first else {
            throw .init(.invalidParams("txID"), description: "TxID (hex string) is required.")
        }
        guard let txID = Data(hex: txIDHex), txID.count == BitcoinTx.idLength else {
            throw .init(.invalidParams("txID"), description: "TxID hex encoding or length is invalid.")
        }
        self.txID = txID
    }

    let request: JSONRequest
    let txID: TxID

    public func run(blockchain: BlockchainService) async throws(RPCError) -> JSONResponse {

        guard let tx = await blockchain.getTx(txID) else {
            throw .init(.invalidParams("txID"), description: "Transaction not found.")
        }
        let ins = tx.ins.map {
            Output.Input(
                tx: $0.outpoint.txID.hex,
                output: $0.outpoint.txOut
            )
        }
        let outs = tx.outs.map {
            Output.Output(
                raw: $0.binaryData.hex,
                amount: $0.value,
                script: $0.script.binaryData.hex
            )
        }
        let result = Output(
            id: tx.id.hex,
            witnessID: tx.witnessID.hex,
            inputs: ins,
            outputs: outs
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-transaction"
    public static let params = "<transaction-id>"
    public static let description = "Returns transaction data for the specified transaction ID."
}
