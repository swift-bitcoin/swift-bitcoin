import Foundation

public protocol BinaryEncodingPrimitive: BinaryCodable {}

extension BinaryEncodingPrimitive {

    public init(from decoder: inout BinaryDecoder, format: BinaryFormat?) throws {
        self = try decoder.decodePrimitive()
    }

    public func encode(into encoder: inout BinaryEncoder, format: BinaryFormat?) {
        encoder.encode(self)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        counter.countPrimitive(self)
    }
}

extension Int: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int8: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int16: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int32: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int64: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt8: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt16: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt32: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt64: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Bool: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Float: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Double: BinaryEncodingPrimitive {
    public typealias BinaryFormat = Never
    public typealias DecodingError = BinaryDecodingError
}
