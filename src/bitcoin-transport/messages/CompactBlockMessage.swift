import Foundation
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

extension CompactBlockMessage {

    public init?(_ data: Data) {
        guard data.count >= 1 else { return nil }
        var data = data

        guard let header = try? Block(data, encoding: .headerOnly) else { return nil }
        self.header = header
        data = data.dropFirst(Block.headerSize) // Data does not include the empty transaction array

        guard data.count >= MemoryLayout<UInt64>.size else { return nil }
        let nonce = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        self.nonce = nonce
        data = data.dropFirst(MemoryLayout<UInt64>.size)

        guard let txIDCount = data.varInt else { return nil }
        data = data.dropFirst(txIDCount.varIntSize)
        var txIDs = [UInt64]()
        for _ in 0 ..< txIDCount {
            guard data.count >= 6 else { return nil }
            let identifier = (data.prefix(6) + Data(count: 2)).withUnsafeBytes {
                $0.loadUnaligned(as: UInt64.self)
            }
            txIDs.append(identifier)
            data = data.dropFirst(6)
        }
        self.txIDs = txIDs

        guard let txCount = data.varInt else { return nil }
        data = data.dropFirst(txCount.varIntSize)
        var txs = [PrefilledTransaction]()
        var previousIndex = -1
        for _ in 0 ..< txCount {
            guard let tx = PrefilledTransaction(data, previousIndex: previousIndex) else { return nil }
            previousIndex = tx.index
            txs.append(tx)
            data = data.dropFirst(tx.size)
        }
        self.txs = txs
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(header.data(encoding: .headerOnly))
        offset = ret.addBytes(nonce, at: offset)

        offset = ret.addData(Data(varInt: UInt64(txIDs.count)), at: offset)
        for identifier in txIDs {
            let data = withUnsafeBytes(of: UInt64(identifier)) {
                Data($0)
            }
            // Keep only 6 less significant bytes.
            offset = ret.addData(data.prefix(6), at: offset)
        }

        offset = ret.addData(Data(varInt: UInt64(txs.count)), at: offset)

        var previousIndex = Int?.none
        for tx in txs {
            offset = ret.addData(tx.getData(previousIndex: previousIndex), at: offset)
            previousIndex = tx.index
        }

        return ret
    }

    var size: Int {
        Block.headerSize + MemoryLayout<UInt64>.size + UInt64(txIDs.count).varIntSize + txIDs.count * 6 + UInt64(txs.count).varIntSize + txs.reduce(0) { $0 + $1.size }
    }
}
