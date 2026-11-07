import BinaryParsing
import Foundation

/// Encode and decode binary data with custom binary format.
///
/// Because the associated ``BinaryEncodable/BinaryFormat`` and ``BinaryDecodable/BinaryFormat`` share their identifier, these must be the same type.
///
/// If the Swift Language changes in the future to allow for different `BinaryFormat` types to be defined, this protocol can also be declared as `protocol BinaryCodable<BinaryFormat>: BinaryEncodable, BinaryDecodable {}`.
///
public typealias BinaryCodable = BinaryEncodable & BinaryDecodable

public protocol BinaryEncodable {
    associatedtype BinaryFormat

    func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?)
    func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws
}

extension BinaryEncodable {
    public func countBytes(into counter: inout BinarySizeCounter) {
        countBytes(into: &counter, format: nil)
    }

    public func encode(into out: inout OutputRawSpan) throws {
        try encode(into: &out, format: nil)
    }

    public func binarySize(format: BinaryFormat?) -> Int {
        var counter = BinarySizeCounter()
        countBytes(into: &counter, format: format)
        return counter.size
    }

    public func data(binaryFormat: BinaryFormat?) -> Data {
        let maybeData = try? Data(capacity: binarySize(format: binaryFormat)) { out in
            try encode(into: &out, format: binaryFormat)
        }
        return maybeData ?? .init()
    }

    /// The external binary representation's length in bytes.
    public var binarySize: Int {
        binarySize(format: nil)
    }

    /// The instance's external binary representation.
    public var data: Data {
        data(binaryFormat: nil)
    }
}

public protocol BinaryDecodable {
    associatedtype BinaryFormat

    init(parsing input: inout ParserSpan, format: BinaryFormat?) throws
}

extension BinaryDecodable {
    public init(parsing input: inout ParserSpan) throws {
        try self.init(parsing: &input, format: nil)
    }

    public init(_ data: Data, binaryFormat: BinaryFormat?) throws {
        var input = ParserSpan(data.bytes)
        try self.init(parsing: &input, format: binaryFormat)
    }

    /// Creates a new instance from an external binary representation.
    /// - Parameter data: The binary representation to decode.
    ///
    /// This initializer is generic over `DataProtocol`  meaning it can be passed a `Data` instance or a `UInt8` array.
    public init(_ data: Data) throws {
        try self.init(data, binaryFormat: nil)
    }
}
