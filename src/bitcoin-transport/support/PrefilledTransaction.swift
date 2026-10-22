import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBase

/// BIP152: A `PrefilledTransaction` structure is used in `HeaderAndShortIDs` to provide a list of a few transactions explicitly.
public struct PrefilledTransaction: Equatable {

    public init(index: Int, tx: Transaction) {
        self.index = index
        self.tx = tx
    }

    /// The index into the block at which this transaction is.
    ///
    /// Compact Size, differentially encoded since the last `PrefilledTransaction` in a list.
    ///
    public let index: Int

    /// The transaction which is in the block at index index.
    ///
    /// As encoded in "tx" messages sent in response to getdata `MSG_TX`.
    ///
    public let tx: Transaction
}

extension PrefilledTransaction: BinaryCodable {

    public struct BinaryFormat {
        let previousIndex: Int
    }

    public init(parsing input: inout ParserSpan, format: BinaryFormat?) throws {
        let indexDiff = try VarInt(parsing: &input).value
        index = indexDiff + (format?.previousIndex ?? -1) + 1
        tx = try Transaction(parsing: &input)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        let indexDiff = if let previousIndex = format?.previousIndex {
            index - previousIndex - 1
        } else {
            index
        }
        counter.count(VarInt(indexDiff))
        counter.count(tx)
    }

    public func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws {
        let indexDiff = if let previousIndex = format?.previousIndex {
            index - previousIndex - 1
        } else {
            index
        }
        try VarInt(indexDiff).encode(into: &out)
        try tx.encode(into: &out)
    }
}
