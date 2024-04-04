import Foundation

/// A `BlockTransactionsRequest`  (i.e. ``GetBlockTransactionsMessage``) structure is used to list transaction indexes in a block being requested.
///
/// The `getblocktxn` message is defined as a message containing a serialized `BlockTransactionsRequest` message and `pchCommand == "getblocktxn"`.
///
public struct GetBlockTransactionsMessage: Equatable {

    public init(blockHash: Data, transactionIndices: [Int]) {
        self.blockHash = blockHash
        self.transactionIndices = transactionIndices
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
    public let transactionIndices: [Int]
}

extension GetBlockTransactionsMessage {

    public init?(_ data: Data) {
        var data = data

        guard data.count >= 32 else { return nil }
        let blockHash = data[..<data.startIndex.advanced(by: 32)]
        self.blockHash = Data(blockHash)
        data = data.dropFirst(blockHash.count)

        guard let transactionCount = data.varInt else { return nil }
        data = data.dropFirst(transactionCount.varIntSize)

        var transactionIndices = [Int]()
        var previousIndex = -1
        for _ in 0 ..< transactionCount {
            guard let indexDiff = data.varInt else { return nil }
            let index = Int(indexDiff) + previousIndex + 1
            transactionIndices.append(index)
            data = data.dropFirst(indexDiff.varIntSize)
            previousIndex = index
        }
        self.transactionIndices = transactionIndices
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(blockHash)
        offset = ret.addData(Data(varInt: UInt64(transactionIndices.count)), at: offset)

        var previousIndex = Int?.none
        for index in transactionIndices {
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
        32 + UInt64(transactionIndices.count).varIntSize + transactionIndices.reduce(0) { $0 + UInt64($1).varIntSize }
    }
}
