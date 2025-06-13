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
    public init(from decoder: inout BinaryDecoder) throws {
        value = try decoder.decode()
        script = try Script(prefixedFrom: &decoder)
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(value)
        script.encodePrefixed(to: &encoder)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(value)
        script.encodingSizePrefixed(&counter)
    }

    var valueData: Data {
        var encoder = BinaryEncoder(size: valueSize)
        encoder.encode(value)
        return encoder.data
    }

    var valueSize: Int {
        var counter = BinaryEncodingSizeCounter()
        counter.count(value)
        return counter.size
    }
}
