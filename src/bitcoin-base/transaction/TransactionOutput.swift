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
        value = try Int(parsing: &input, storedAsLittleEndian: UInt64.self)
        if format == .valueOnly {
            preconditionFailure("Cannot parse an amount into a transaction output without a script.")
        } else {
            script = try .init(parsing: &input, format: .prefixed)
        }
    }

    public init(from decoder: inout BinaryDecoder, format: BinaryFormat?) throws {
        value = try decoder.decode()
        if format == .valueOnly {
            preconditionFailure("Cannot parse an amount into a transaction output without a script.")
        } else {
            script = try Script(from: &decoder, format: .prefixed)
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        counter.count(UInt64.self)
        if format != .valueOnly {
            script.countBytes(into: &counter, format: .prefixed)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws {
        out.append(value == -1 ? UInt64.max : UInt64(value), as: UInt64.self, .littleEndian)
        if format != .valueOnly {
            try script.encode(into: &out, format: .prefixed)
        }
    }

    /*
    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(value)
        script.encodePrefixed(to: &encoder)
    }
    */
}
