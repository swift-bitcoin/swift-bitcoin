import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain

/// A `HeaderAndShortIDs` (i.e. ``CompactBlockMessage``)  structure is used to relay a block header, the short transactions IDs used for matching already-available transactions, and a select few transactions which we expect a peer may be missing.
///
/// The `cmpctblock` message is defined as a message containing a serialized `HeaderAndShortIDs` message and `pchCommand == "cmpctblock"`.
///
public struct CompactBlockMessage: Equatable {

    public init(header: Block, nonce: UInt64, txIDs: [UInt64], txs: [PrefilledTransaction]) {
        precondition(header.txs.isEmpty)
        self.header = header
        self.nonce = nonce
        self.txIDs = txIDs
        self.txs = txs
    }

    /// The header of the block being provided.
    ///
    /// First 80 bytes of the block as defined by the encoding used by "block" messages.
    ///
    public let header: Block

    /// A nonce for use in short transaction ID calculations.
    ///
    /// Little Endian. 8 bytes.
    ///
    public let nonce: UInt64

    /// The short transaction IDs calculated from the transactions which were not provided explicitly in `prefilledtxn`.
    ///
    /// `shortids_length`: The number of short transaction IDs in shortids (i.e. `block tx count - prefilledtxn_length`)
    ///
    public let txIDs: [UInt64]

    /// Used to provide the coinbase transaction and a select few which we expect a peer may be missing.
    ///
    /// `prefilledtxn_length`: The number of prefilled transactions in `prefilledtxn` (i.e. `block tx count - shortids_length`).
    ///
    public let txs: [PrefilledTransaction]
}

extension CompactBlockMessage: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        header = try Block(parsing: &input, format: .headerOnly)
        nonce = try UInt64(parsingLittleEndian: &input)

        let txIDCount = try VarInt(parsing: &input).value
        var txIDs = [UInt64]()
        for _ in 0 ..< txIDCount {
            let part1 = try UInt32(parsingLittleEndian: &input)
            let part2 = try UInt16(parsingLittleEndian: &input)
            let identifier = (UInt64(part2) << 32) | UInt64(part1)
            txIDs.append(identifier)
        }
        self.txIDs = txIDs

        let txCount = try VarInt(parsing: &input).value
        var txs = [PrefilledTransaction]()
        var previousIndex = -1
        for _ in 0 ..< txCount {
            let tx = try PrefilledTransaction(parsing: &input, format: .init(previousIndex: previousIndex))
            previousIndex = tx.index
            txs.append(tx)
        }
        self.txs = txs
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(header, format: .headerOnly)
        counter.count(UInt64.self)
        counter.count(VarInt(txIDs.count))
        counter.countSize((MemoryLayout<UInt32>.size + MemoryLayout<UInt16>.size) * txIDs.count)
        counter.count(VarInt(txs.count))
        var previousIndex = Int?.none
        for tx in txs {
            counter.count(tx, format: previousIndex == nil ? nil : .init(previousIndex: previousIndex!))
            previousIndex = tx.index
        }
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try header.encode(into: &out, format: .headerOnly)
        out.append(nonce, as: UInt64.self, .littleEndian)

        try VarInt(txIDs.count).encode(into: &out)
        for identifier in txIDs {
            let part1 = UInt32(truncatingIfNeeded: identifier & 0xFFFFFFFF) // lower 4 bytes
            let part2 = UInt16(truncatingIfNeeded: (identifier >> 32) & 0xFFFF) // next 2 bytes
            out.append(part1, as: UInt32.self, .littleEndian)
            out.append(part2, as: UInt16.self, .littleEndian)
        }

        try VarInt(txs.count).encode(into: &out)
        var previousIndex = Int?.none
        for tx in txs {
            try tx.encode(into: &out, format: previousIndex == nil ? nil : .init(previousIndex: previousIndex!))
            previousIndex = tx.index
        }
    }
}
