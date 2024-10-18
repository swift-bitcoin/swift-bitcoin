import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

public struct GetTransactionCommand: Sendable {

    internal struct Output: Sendable, CustomStringConvertible, Codable {

        public struct Input: Sendable, Codable {
            public let transaction: String
            public let output: Int
        }

        public struct Output: Sendable, Codable {
            public let raw: String
            public let amount: BitcoinAmount
            public let script: String
        }

        public var description: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let value = try! encoder.encode(self)
            return String(data: value, encoding: .utf8)!
        }

        public let id: String
        public let witnessID: String
        public let inputs: [Input]
        public let outputs: [Output]
    }

    public init(bitcoinService: BitcoinService) {
        self.bitcoinService = bitcoinService
    }

    let bitcoinService: BitcoinService

    public func run(_ request: JSONRequest) async throws -> JSONResponse {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(transactionIDHex) = first else {
            throw RPCError(.invalidParams("transactionID"), description: "TransactionID (hex string) is required.")
        }
        guard let transactionID = Data(hex: transactionIDHex), transactionID.count == BitcoinTransaction.idLength else {
            throw RPCError(.invalidParams("transactionID"), description: "TransactionID hex encoding or length is invalid.")
        }
        guard let transaction = await bitcoinService.getTransaction(transactionID) else {
            throw RPCError(.invalidParams("transactionID"), description: "Transaction not found.")
        }
        let inputs = transaction.inputs.map {
            Output.Input(
                transaction: $0.outpoint.transactionID.hex,
                output: $0.outpoint.outputIndex
            )
        }
        let outputs = transaction.outputs.map {
            Output.Output(
                raw: $0.data.hex,
                amount: $0.value,
                script: $0.script.data.hex
            )
        }
        let result = Output(
            id: transaction.id.hex,
            witnessID: transaction.witnessID.hex,
            inputs: inputs,
            outputs: outputs
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-transaction"
}
