import Foundation
import BinaryParsing
import BitcoinCrypto

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

extension GetBlockTransactionsMessage: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        blockHash = try Data([UInt8](parsing: &input, byteCount: Int(hashLength)))
        let txCount = try VarInt(parsing: &input).value

        var txIndices = [Int]()
        var previousIndex = -1
        for _ in 0 ..< txCount {
            let indexDiff = try VarInt(parsing: &input).value
            let index = indexDiff + previousIndex + 1
            txIndices.append(index)
            previousIndex = index
        }
        self.txIndices = txIndices
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.countSize(hashLength)
        counter.count(VarInt(txIndices.count))
        var previousIndex = Int?.none
        for index in txIndices {
            let indexDiff = if let previousIndex {
                index - previousIndex - 1
            } else {
                index
            }
            previousIndex = index
            counter.count(VarInt(indexDiff))
        }
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(contentsOf: blockHash)
        try VarInt(txIndices.count).encode(into: &out)
        var previousIndex = Int?.none
        for index in txIndices {
            let indexDiff = if let previousIndex {
                index - previousIndex - 1
            } else {
                index
            }
            previousIndex = index
            try VarInt(indexDiff).encode(into: &out)
        }
    }
}

fileprivate let hashLength = SHA256.Digest.byteCount // 32 bytes
