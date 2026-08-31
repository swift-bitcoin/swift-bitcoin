import Foundation
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
    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        value = try decoder.decode()
        script = try Script(prefixedFrom: &decoder)
    }

    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(value)
        script.encodePrefixed(to: &encoder)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(value)
        script.countBytesPrefixed(into: &counter)
    }

    // TODO: Use a custom binary format for just the value
    var valueData: Data {
        var encoder = BinaryEncoder(size: valueSize)
        encoder.encode(value)
        return encoder.data
    }

    var valueSize: Int {
        var counter = BinarySizeCounter()
        counter.count(value)
        return counter.size
    }
}

// Binary parsing

import BinaryParsing

extension TransactionOutput {
    public init(parsing input: inout ParserSpan) throws {
        value = try Int(parsing: &input, storedAsLittleEndian: UInt64.self)
        script = try .init(parsing: &input)
    }
}

extension TransactionOutput {
    public func encode(into out: inout OutputRawSpan) throws {
        out.append(UInt64(value).littleEndian, as: UInt64.self)
        try script.encode(into: &out)
    }
}
