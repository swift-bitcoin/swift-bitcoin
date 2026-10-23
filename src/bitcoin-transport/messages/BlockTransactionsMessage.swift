import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBase

/// BIP152: A `BlockTransactions` structure is used to provide some of the transactions in a block, as requested.
///
/// The `blocktxn` message is defined as a message containing a serialized `BlockTransactions` message and `pchCommand == "blocktxn"`.
///
public struct BlockTransactionsMessage: Equatable {

    public init(blockHash: Data, txs: [Transaction]) {
        self.blockHash = blockHash
        self.txs = txs
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
    public let txs: [Transaction]
}

extension BlockTransactionsMessage: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        blockHash = try Data([UInt8](parsing: &input, byteCount: Block.idLength))
        let txCount = try VarInt(parsing: &input).value
        var txs = [Transaction]()
        for _ in 0 ..< txCount {
            let tx = try Transaction(parsing: &input)
            txs.append(tx)
        }
        self.txs = txs
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.countSize(Block.idLength)
        counter.count(VarInt(txs.count))
        for tx in txs {
            tx.countBytes(into: &counter)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(contentsOf: blockHash)
        try VarInt(txs.count).encode(into: &out)
        for tx in txs {
            try tx.encode(into: &out)
        }
    }
}
