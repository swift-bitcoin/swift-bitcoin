import Foundation
import BitcoinBase
import BitcoinBlockchain

public extension BitcoinService {

    struct BlockchainInfo: Sendable, CustomStringConvertible, Codable {
        public var description: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let value = try! encoder.encode(self)
            return String(data: value, encoding: .utf8)!
        }

        public let headers: Int
        public let blocks: Int
        public let hashes: [String]
    }

    struct TransactionInfo: Sendable, CustomStringConvertible, Codable {

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

        public let identifier: String
        public let inputs: [Input]
        public let outputs: [Output]
    }


    struct BlockInfo: Sendable, CustomStringConvertible, Codable {
        public var description: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let value = try! encoder.encode(self)
            return String(data: value, encoding: .utf8)!
        }

        public let identifier: String
        public let previous: String
        public let transactions: [String]
    }

    func getBlockInfo(_ identifier: BlockIdentifier) -> BlockInfo? {
        guard let index = headers.firstIndex(where: { $0.identifier == identifier }), index < transactions.endIndex else {
            return .none
        }
        let header = headers[index]
        let transactions = transactions[index].map { $0.identifier.hex }
        return .init(
            identifier: header.identifierHex,
            previous: header.previous.hex,
            transactions: transactions
        )
    }

    func getTransactionInfo(_ identifier: TransactionIdentifier) -> TransactionInfo? {
        var blockIndex = Int?.none
        var transactionIndex = Int?.none
        for i in transactions.indices {
            if let j = transactions[i].firstIndex(where: { $0.identifier == identifier}) {
                transactionIndex = j
                blockIndex = i
                break
            }
        }
        guard let blockIndex, let transactionIndex else { return .none }
        let transaction = transactions[blockIndex][transactionIndex]
        let inputs = transaction.inputs.map {
            TransactionInfo.Input(
                transaction: $0.outpoint.transactionIdentifier.hex,
                output: $0.outpoint.outputIndex
            )
        }
        let outputs = transaction.outputs.map {
            TransactionInfo.Output(
                raw: $0.data.hex,
                amount: $0.value,
                script: $0.script.data.hex
            )
        }
        return .init(
            identifier: transaction.identifier.hex,
            inputs: inputs,
            outputs: outputs
        )
    }

    func getBlockchainInfo() -> BlockchainInfo {
        .init(
            headers: headers.count,
            blocks: transactions.count,
            hashes: headers.map { $0.identifierHex }
        )
    }
}
