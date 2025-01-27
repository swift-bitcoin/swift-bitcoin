import Foundation

public protocol BinaryEncodingPrimitive: BinaryCodable {}

extension BinaryEncodingPrimitive {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        self = try decoder.decodePrimitive()
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(self)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.countPrimitive(self)
    }
}

extension Int: BinaryEncodingPrimitive {}
extension Int8: BinaryEncodingPrimitive {}
extension Int16: BinaryEncodingPrimitive {}
extension Int32: BinaryEncodingPrimitive {}
extension Int64: BinaryEncodingPrimitive {}

extension UInt: BinaryEncodingPrimitive {}
extension UInt8: BinaryEncodingPrimitive {}
extension UInt16: BinaryEncodingPrimitive {}
extension UInt32: BinaryEncodingPrimitive {}
extension UInt64: BinaryEncodingPrimitive {}
