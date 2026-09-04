import Foundation
import BinaryParsing
import BitcoinCrypto

/// The output of a ``Transaction``. While unspent also referred to as a _coin_.
public struct TransactionOutput: Equatable, Sendable {

    /// Creates an output out of an amount (value) and a locking script.
    /// - Parameters:
    ///   - value: A Satoshi amount represented by this output.
    ///   - script: The script encumbering the specified value.
    public init(value: Amount, script: Script = .empty) {
        self.value = value
        self.script = script
    }

    /// The amount in _satoshis_ encumbered by this output.
    public var value: Amount

    /// The script that locks this output.
    public var script: Script
}

/// Data extensions.
extension TransactionOutput: BinaryCodable {

    public enum BinaryFormat {
        case valueOnly
    }

    public init(parsing input: inout ParserSpan, format: BinaryFormat?) throws {
        value = try Int(parsing: &input, storedAsLittleEndian: Int64.self)
        if format == .valueOnly {
            preconditionFailure("Cannot parse an amount into a transaction output without a script.")
        } else {
            script = try .init(parsing: &input, format: .prefixed)
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        counter.count(Int64.self)
        if format != .valueOnly {
            script.countBytes(into: &counter, format: .prefixed)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws {
        out.append(Int64(value), as: Int64.self, .littleEndian)
        if format != .valueOnly {
            try script.encode(into: &out, format: .prefixed)
        }
    }
}
