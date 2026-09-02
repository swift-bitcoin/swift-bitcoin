import Foundation
import BinaryParsing

/// Encode and decode binary data with custom binary format.
///
/// Because the associated ``BinaryEncodable/BinaryFormat`` and ``BinaryDecodable/BinaryFormat`` share their identifier, these must be the same type.
///
/// If the Swift Language changes in the future to allow for different `BinaryFormat` types to be defined, this protocol can also be declared as `protocol BinaryCodable<BinaryFormat>: BinaryEncodable, BinaryDecodable {}`.
///
public typealias BinaryCodable = BinaryEncodable & BinaryDecodableLegacy // Temporarilly mixing *Legacy and new protocol
public typealias BinaryCodableLegacy = BinaryEncodableLegacy & BinaryDecodableLegacy // Temporarilly mixing *Legacy and new protocol

/// Legacy encodable protocol based on BinaryEncoder instead of OutputRawSpan
public protocol BinaryEncodableLegacy {

    associatedtype BinaryFormat

    func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?)
    func encode(into encoder: inout BinaryEncoder, format: BinaryFormat?)
}

public extension BinaryEncodableLegacy {

    func countBytes(into counter: inout BinarySizeCounter) {
        countBytes(into: &counter, format: nil)
    }

    func encode(into encoder: inout BinaryEncoder) {
        encode(into: &encoder, format: nil)
    }

    func binarySize(format: BinaryFormat?) -> Int {
        var counter = BinarySizeCounter()
        countBytes(into: &counter, format: format)
        return counter.size
    }

    func data(binaryFormat: BinaryFormat?) -> Data {
        var counter = BinarySizeCounter()
        countBytes(into: &counter, format: binaryFormat)
        var encoder = BinaryEncoder(counter)
        encode(into: &encoder, format: binaryFormat)
        return encoder.data
    }

    /// The external binary representation's length in bytes.
    var binarySize: Int {
        binarySize(format: nil)
    }

    /// The instance's external binary representation.
    var data: Data {
        data(binaryFormat: nil)
    }
}

/// Legacy decodable protocol based on BinaryDecoder instead of ParserSpan
public protocol BinaryDecodableLegacy {
    associatedtype BinaryFormat

    init(from decoder: inout BinaryDecoder, format: BinaryFormat?) throws
}

public extension BinaryDecodableLegacy {

    init(from decoder: inout BinaryDecoder) throws {
        try self.init(from: &decoder, format: nil)
    }

    init<D: DataProtocol>(_ data:D, binaryFormat: BinaryFormat?) throws {
        var decoder = BinaryDecoder(data)
        try self.init(from: &decoder, format: binaryFormat)
    }

    /// Creates a new instance from an external binary representation.
    /// - Parameter data: The binary representation to decode.
    ///
    /// This initializer is generic over `DataProtocol`  meaning it can be passed a `Data` instance or a `UInt8` array.
    init<D: DataProtocol>(_ data: D) throws {
        try self.init(data, binaryFormat: nil)
    }
}

public protocol BinaryEncodable {

    associatedtype BinaryFormat

    func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?)
    func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws
}

public extension BinaryEncodable {

    func countBytes(into counter: inout BinarySizeCounter) {
        countBytes(into: &counter, format: nil)
    }

    func encode(into out: inout OutputRawSpan) throws {
        try encode(into: &out, format: nil)
    }

    func binarySize(format: BinaryFormat?) -> Int {
        var counter = BinarySizeCounter()
        countBytes(into: &counter, format: format)
        return counter.size
    }

    func data(binaryFormat: BinaryFormat?) -> Data {
        let maybeData = try? Data(capacity: binarySize(format: binaryFormat)) { out in
            try encode(into: &out, format: binaryFormat)
        }
        return maybeData ?? .init()
    }

    /// The external binary representation's length in bytes.
    var binarySize: Int {
        binarySize(format: nil)
    }

    /// The instance's external binary representation.
    var data: Data {
        data(binaryFormat: nil)
    }
}

public protocol BinaryDecodable: ExpressibleByParsing {
    associatedtype BinaryFormat

    init(parsing input: inout ParserSpan, format: BinaryFormat?) throws
}

public extension BinaryDecodable {

    init(parsing input: inout ParserSpan) throws {
        try self.init(parsing: &input, format: nil)
    }

    init(_ data: Data, binaryFormat: BinaryFormat?) throws {
        var input = ParserSpan(data.bytes)
        try self.init(parsing: &input)
    }

    /// Creates a new instance from an external binary representation.
    /// - Parameter data: The binary representation to decode.
    ///
    /// This initializer is generic over `DataProtocol`  meaning it can be passed a `Data` instance or a `UInt8` array.
    init(_ data: Data) throws {
        try self.init(data, binaryFormat: nil)
    }
}
