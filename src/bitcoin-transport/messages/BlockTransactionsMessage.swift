import Foundation
import BitcoinBase

/// A `BlockTransactions` (i.e. ``BlockTransactionsMessage``) structure is used to provide some of the transactions in a block, as requested.
///
/// The `blocktxn` message is defined as a message containing a serialized `BlockTransactions` message and `pchCommand == "blocktxn"`.
///
public struct BlockTransactionsMessage: Equatable {

    public init(blockHash: Data, transactions: [BitcoinTransaction]) {
        self.blockHash = blockHash
        self.transactions = transactions
    }

    /// The blockhash of the block which the transactions being provided are in.
    ///
    /// The output from a double-SHA256 of the block header, as used elsewhere. 32 bytes.
    ///
    public let blockHash: Data

    /// The transactions provided.
    ///
    /// As encoded in "tx" messages in response to getdata `MSG_TX`.
    ///
    /// `transactions_length`: The number of transactions provided. CompactSize.
    ///
    public let transactions: [BitcoinTransaction]
}

extension BlockTransactionsMessage {

    public init?(_ data: Data) {
        var data = data

        guard data.count >= 32 else { return nil }
        let blockHash = data.prefix(32)
        self.blockHash = Data(blockHash)
        data = data.dropFirst(blockHash.count)

        guard let transactionCount = data.varInt else { return nil }
        data = data.dropFirst(transactionCount.varIntSize)

        var transactions = [BitcoinTransaction]()
        for _ in 0 ..< transactionCount {
            guard let transaction = BitcoinTransaction(data) else { return nil }
            transactions.append(transaction)
            data = data.dropFirst(transaction.size)
        }
        self.transactions = transactions
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(blockHash)
        offset = ret.addData(Data(varInt: UInt64(transactions.count)), at: offset)
        for transaction in transactions {
            offset = ret.addData(transaction.data, at: offset)
        }
        return ret
    }

    var size: Int {
        32 + UInt64(transactions.count).varIntSize + transactions.reduce(0) { $0 + $1.size }
    }
}
