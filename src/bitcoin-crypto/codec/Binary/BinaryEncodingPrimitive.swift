import Foundation

public protocol BinaryEncodingPrimitive: BinaryCodable, CustomBinaryCodable {}

extension BinaryEncodingPrimitive {

    public init(from decoder: inout BinaryDecoder, encoding: Encoding?) throws {
        self = try decoder.decodePrimitive()
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Encoding?) {
        encoder.encode(self)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Encoding?) {
        counter.countPrimitive(self)
    }
}

extension Int: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int8: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int16: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int32: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Int64: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt8: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt16: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt32: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension UInt64: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Bool: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Float: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}

extension Double: BinaryEncodingPrimitive {
    public typealias Encoding = Never
    public typealias DecodingError = BinaryDecodingError
}
