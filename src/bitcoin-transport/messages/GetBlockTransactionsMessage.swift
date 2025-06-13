import Foundation

/// BIP152: A `BlockTransactionsRequest` structure is used to list transaction indexes in a block being requested.
///
/// The `getblocktxn` message is defined as a message containing a serialized `BlockTransactionsRequest` message and `pchCommand == "getblocktxn"`.
///
public struct GetBlockTransactionsMessage: Equatable {

    public init(blockHash: Data, txIndices: [Int]) {
        self.blockHash = blockHash
        self.txIndices = txIndices
    }

    /// The blockhash of the block which the transactions being requested are in.
    ///
    /// The output from a double-SHA256 of the block header, as used elsewhere. 32 bytes.
    ///
    public let blockHash: Data

    /// The indexes of the transactions being requested in the block.
    ///
    /// List of CompactSizes. Differentially encoded.
    ///
    /// `indexes_length`: The number of transactions being requested. `CompactSize` (1 or 3 bytes). As used to encode array lengths elsewhere.
    ///
    public let txIndices: [Int]
}

extension GetBlockTransactionsMessage {

    public init?(_ data: Data) {
        var data = data

        guard data.count >= 32 else { return nil }
        let blockHash = data.prefix(32)
        self.blockHash = Data(blockHash)
        data = data.dropFirst(blockHash.count)

        guard let txCount = data.varInt else { return nil }
        data = data.dropFirst(txCount.varIntSize)

        var txIndices = [Int]()
        var previousIndex = -1
        for _ in 0 ..< txCount {
            guard let indexDiff = data.varInt else { return nil }
            let index = Int(indexDiff) + previousIndex + 1
            txIndices.append(index)
            data = data.dropFirst(indexDiff.varIntSize)
            previousIndex = index
        }
        self.txIndices = txIndices
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(blockHash)
        offset = ret.addData(Data(varInt: UInt64(txIndices.count)), at: offset)

        var previousIndex = Int?.none
        for index in txIndices {
            let indexDiff = if let previousIndex {
                index - previousIndex - 1
            } else {
                index
            }
            previousIndex = index
            offset = ret.addData(Data(varInt: UInt64(indexDiff)), at: offset)
        }
        return ret
    }

    var size: Int {
        32 + UInt64(txIndices.count).varIntSize + txIndices.reduce(0) { $0 + UInt64($1).varIntSize }
    }
}
