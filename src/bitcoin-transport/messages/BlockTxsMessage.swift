import Foundation
import BitcoinBase

/// BIP152: A `BlockTransactions` structure is used to provide some of the transactions in a block, as requested.
///
/// The `blocktxn` message is defined as a message containing a serialized `BlockTransactions` message and `pchCommand == "blocktxn"`.
///
public struct BlockTxsMessage: Equatable {

    public init(blockHash: Data, txs: [BitcoinTx]) {
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
    public let txs: [BitcoinTx]
}

extension BlockTxsMessage {

    public init?(_ data: Data) {
        var data = data

        guard data.count >= 32 else { return nil }
        let blockHash = data.prefix(32)
        self.blockHash = Data(blockHash)
        data = data.dropFirst(blockHash.count)

        guard let txCount = data.varInt else { return nil }
        data = data.dropFirst(txCount.varIntSize)

        var txs = [BitcoinTx]()
        for _ in 0 ..< txCount {
            guard let tx = try? BitcoinTx(binaryData: data) else { return nil }
            txs.append(tx)
            data = data.dropFirst(tx.binarySize)
        }
        self.txs = txs
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(blockHash)
        offset = ret.addData(Data(varInt: UInt64(txs.count)), at: offset)
        for tx in txs {
            offset = ret.addData(tx.binaryData, at: offset)
        }
        return ret
    }

    var size: Int {
        32 + UInt64(txs.count).varIntSize + txs.reduce(0) { $0 + $1.binarySize }
    }
}
