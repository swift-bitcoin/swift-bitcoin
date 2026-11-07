import BinaryParsing
import BitcoinCrypto
import Foundation

/// A reference to a specific ``TransactionOutput`` of a particular ``Transaction`` which is stored in a ``Transaction/Input``.
public struct Outpoint: Equatable, Hashable, Sendable {
    /// Creates a reference to an output of a previous transaction.
    /// - Parameters:
    ///   - tx: The identifier for the previous transaction being referenced.
    ///   - out: The index within the previous transaction corresponding to the desired output.
    public init(tx: TransactionIdentifier, out: Int) {
        self.txID = tx
        self.out = out
    }

    // The identifier for the transaction containing the referenced output.
    public var txID: TransactionIdentifier

    /// The index of an output in the referenced transaction.
    public var out: Int

    /// The outpoint meant for the single coinbase transaction input. Also known as _null_ outpoint or _null prevout_.
    public static let coinbase = Self(
        tx: TransactionIdentifier(Hash256(.init(repeating: 0))), // All zeroes
        out: 0xffff_ffff // or `UInt32.max`
    )
}

/// Data extensions.
extension Outpoint: BinaryCodable {
    public init(parsing input: inout ParserSpan, format: Never?) throws {
        let tx = try TransactionIdentifier(parsing: &input)
        let out = Int(try UInt32(parsingLittleEndian: &input))
        self.init(tx: tx, out: out)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.countSize(Hash256.byteCount)
        counter.count(UInt32.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        txID.encode(into: &out)
        out.append(UInt32(self.out), as: UInt32.self, .littleEndian)
    }
}
