import Foundation
import BitcoinBlockchain

/// A `HeaderAndShortIDs` (i.e. ``CompactBlockMessage``)  structure is used to relay a block header, the short transactions IDs used for matching already-available transactions, and a select few transactions which we expect a peer may be missing.
///
/// The `cmpctblock` message is defined as a message containing a serialized `HeaderAndShortIDs` message and `pchCommand == "cmpctblock"`.
///
public struct CompactBlockMessage: Equatable {

    public init(header: BlockHeader, nonce: UInt64, transactionIdentifiers: [Int], transactions: [PrefilledTransaction]) {
        self.header = header
        self.nonce = nonce
        self.transactionIdentifiers = transactionIdentifiers
        self.transactions = transactions
    }

    /// The header of the block being provided.
    ///
    /// First 80 bytes of the block as defined by the encoding used by "block" messages.
    ///
    public let header: BlockHeader

    /// A nonce for use in short transaction ID calculations.
    ///
    /// Little Endian. 8 bytes.
    ///
    public let nonce: UInt64

    /// The short transaction IDs calculated from the transactions which were not provided explicitly in `prefilledtxn`.
    ///
    /// `shortids_length`: The number of short transaction IDs in shortids (i.e. `block tx count - prefilledtxn_length`)
    ///
    public let transactionIdentifiers: [Int]

    /// Used to provide the coinbase transaction and a select few which we expect a peer may be missing.
    ///
    /// `prefilledtxn_length`: The number of prefilled transactions in `prefilledtxn` (i.e. `block tx count - shortids_length`).
    ///
    public let transactions: [PrefilledTransaction]
}

extension CompactBlockMessage {

    public init?(_ data: Data) {
        guard data.count >= 1 else { return nil }
        var data = data

        guard let header = BlockHeader(data) else { return nil }
        self.header = header
        data = data.dropFirst(BlockHeader.size)

        guard data.count >= MemoryLayout<UInt64>.size else { return nil }
        let nonce = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        self.nonce = nonce
        data = data.dropFirst(MemoryLayout<UInt64>.size)

        guard let transactionIdentifierCount = data.varInt else { return nil }
        data = data.dropFirst(transactionIdentifierCount.varIntSize)
        var transactionIdentifiers = [Int]()
        for _ in 0 ..< transactionIdentifierCount {
            guard data.count >= 6 else { return nil }
            let identifier = (data + Data(count: 2)).withUnsafeBytes {
                $0.loadUnaligned(as: UInt64.self)
            }
            transactionIdentifiers.append(Int(identifier))
            data = data.dropFirst(6)
        }
        self.transactionIdentifiers = transactionIdentifiers

        guard let transactionCount = data.varInt else { return nil }
        data = data.dropFirst(transactionCount.varIntSize)
        var transactions = [PrefilledTransaction]()
        var previousIndex = -1
        for _ in 0 ..< transactionIdentifierCount {
            guard let transaction = PrefilledTransaction(data, previousIndex: previousIndex) else { return nil }
            previousIndex = transaction.index
            transactions.append(transaction)
            data = data.dropFirst(transaction.size)
        }
        self.transactions = transactions
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(header.data)
        offset = ret.addBytes(nonce, at: offset)

        offset = ret.addData(Data(varInt: UInt64(transactionIdentifiers.count)), at: offset)
        for identifier in transactionIdentifiers {
            let data = withUnsafeBytes(of: UInt64(identifier)) {
                Data($0)
            }
            // Keep only 6 less significant bytes.
            offset = ret.addData(data[..<data.startIndex.advanced(by: 6)], at: offset)
        }

        offset = ret.addData(Data(varInt: UInt64(transactionIdentifiers.count)), at: offset)

        var previousIndex = Int?.none
        for transaction in transactions {
            offset = ret.addData(transaction.getData(previousIndex: previousIndex), at: offset)
            previousIndex = transaction.index
        }

        return ret
    }

    var size: Int {
        BlockHeader.size + MemoryLayout<UInt64>.size + UInt64(transactionIdentifiers.count).varIntSize + transactionIdentifiers.count * 6 + UInt64(transactions.count).varIntSize + transactions.reduce(0) { $0 + $1.size }
    }
}
