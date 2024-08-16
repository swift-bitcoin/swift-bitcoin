import Foundation
import BitcoinCrypto
import BitcoinBase

extension TransactionBlock {

    // MARK: - Initializers

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

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(header.data)
        offset = ret.addData(Data(varInt: .init(transactions.count)), at: offset)
        ret.addData(Data(transactions.map(\.data).joined()), at: offset)
        return ret
    }

    /// Size of data in bytes.
    var size: Int {
        let transactionsSize = transactions.reduce(0) { $0 + $1.size }
        return BlockHeader.size +
               UInt64(transactions.count).varIntSize +
               transactionsSize // Transactions
    }
}
