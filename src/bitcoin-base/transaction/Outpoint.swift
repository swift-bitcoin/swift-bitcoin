import Foundation
import BitcoinCrypto

/// A reference to a specific ``TransactionOutput`` of a particular ``Transaction`` which is stored in a ``Transaction/Input``.
public struct Outpoint: Equatable, Hashable, Sendable {

    /// Creates a reference to an output of a previous transaction.
    /// - Parameters:
    ///   - tx: The identifier for the previous transaction being referenced.
    ///   - out: The index within the previous transaction corresponding to the desired output.
    public init(tx: Transaction.ID, out: Int) {
        precondition(tx.count == Transaction.idLength)
        self.txID = tx
        self.out = out
    }

    // The identifier for the transaction containing the referenced output.
    public let txID: Transaction.ID

    /// The index of an output in the referenced transaction.
    public let out: Int

    /// The outpoint meant for the single coinbase transaction input. Also known as _null_ outpoint or _null prevout_.
    public static let coinbase = Self(
        tx: .init(count: Transaction.idLength), // All zeroes
        out: 0xffffffff // or `UInt32.max`
    )
}

/// Data extensions.
extension Outpoint: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws {
        let tx = try decoder.decode(Transaction.idLength)
        let out = Int(try decoder.decode() as UInt32)
        self.init(tx: tx, out: out)
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(txID)
        encoder.encode(UInt32(out))
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.countSize(Transaction.idLength)
        counter.count(UInt32.self)
    }
}
