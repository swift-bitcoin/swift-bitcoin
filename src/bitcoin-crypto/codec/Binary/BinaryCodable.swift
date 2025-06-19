import Foundation

/// A type that can convert itself into and out of a binary external representation.
///
/// Codable is a type alias for the `BinaryEncodable` and `BinaryDecodable` protocols. When you use Codable as a type or a generic constraint, it matches any type that conforms to both protocols.
public typealias BinaryCodable = BinaryDecodable & BinaryEncodable

/// A type that can encode itself to a binary external representation.
public protocol BinaryEncodable {

    /// Encodes this value into the given binary encoder.
    /// - Parameter encoder: The encoder to write binary data to.
    ///
    /// This function throws an error if any values are invalid for the given encoder’s format.
    func encode(to encoder: inout BinaryEncoder)

    /// Reports the length of the binary representation.
    /// - Parameter counter: The counter to report the instance's encoded size to.
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter)
}

/// A type that can decode itself from an external binary representation.
public protocol BinaryDecodable {

    /// Creates a new instance by decoding from the given decoder.
    init(from decoder: inout BinaryDecoder) throws
}

public extension BinaryEncodable {

    /// The instance's external binary representation.
    var data: Data {
        var encoder = BinaryEncoder(size: dataSize)
        encode(to: &encoder)
        return encoder.data
    }

    /// The external binary representation's length in bytes.
    var dataSize: Int {
        var counter = BinaryEncodingSizeCounter()
        encodingSize(&counter)
        return counter.size
    }
}

public extension BinaryDecodable {

    /// Creates a new instance from an external binary representation.
    /// - Parameter data: The binary representation to decode.
    ///
    /// This initializer is generic over `DataProtocol`  meaning it can be passed a `Data` instance or a `UInt8` array.
    init<D: DataProtocol>(_ data: D) throws {
        var decoder = BinaryDecoder(data)
        try self.init(from: &decoder)
    }
}
