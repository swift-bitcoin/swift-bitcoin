import Foundation
import CryptoUtils

/// A block of transactions.
public struct TransactionBlock: Equatable {

    // MARK: - Initializers

    public init(header: BlockHeader, transactions: [BitcoinTransaction]) {
        self.header = header
        self.transactions = transactions
    }

    /// Initialize from serialized raw data.
    public init?(_ data: Data) {
        // Check we at least have enough data for block header + transactions
        guard data.count > 80 else {
            return nil
        }
        var data = data

        // Header
        guard let header = BlockHeader(data) else {
            return nil
        }
        data = data.dropFirst(BlockHeader.size)
        self.header = header

        guard let transactionCount = data.varInt, transactionCount <= Int.max else {
            return nil
        }
        data = data.dropFirst(transactionCount.varIntSize)

        var transactions = [BitcoinTransaction]()
        for _ in 0 ..< transactionCount {
            guard let transaction = BitcoinTransaction(data) else {
                return nil
            }
            transactions.append(transaction)
        }
        self.transactions = transactions
    }

    // MARK: - Instance Properties

    public let header: BlockHeader
    public let transactions: [BitcoinTransaction]

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data()
        ret.append(header.data)
        ret.append(Data(varInt: .init(transactions.count)))
        ret.append(contentsOf: transactions.map(\.data).joined())
        return ret
    }

    public var identifier: Data {
        Data(hash256(header.data).reversed())
    }

    /// Size of data in bytes.
    var size: Int {
        let transactionsSize = transactions.reduce(0) { $0 + $1.size }
        return UInt64(transactions.count).varIntSize +
               transactionsSize // Transactions
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods

    // No type methods yet.
}
