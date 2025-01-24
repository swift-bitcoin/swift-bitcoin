public struct VarInt: BinaryCodable {

    public init(_ value: Int) {
        rawValue = .init(value)
    }

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let firstByte = try decoder.take() as UInt8
        if firstByte < 0xfd {
            rawValue = UInt64(firstByte)
        } else if firstByte == 0xfd {
            let value = try decoder.take() as UInt16
            rawValue = UInt64(value)
        } else if firstByte == 0xfe {
            let value = try decoder.take() as UInt32
            rawValue = UInt64(value)
        } else {
            rawValue = try decoder.take() as UInt64
        }
    }

    private var rawValue: UInt64

    public var value: Int {
        get { Int(rawValue) }
        set { rawValue = .init(newValue) }
    }

    public func encode(to encoder: inout BinaryEncoder) {
        if rawValue < 0xfd {
            encoder.put(UInt8(rawValue))
        } else if rawValue <= UInt16.max {
            encoder.put(UInt8(0xfd))
            encoder.put(UInt16(rawValue))
        } else if rawValue <= UInt32.max {
            encoder.put(UInt8(0xfe))
            encoder.put(UInt32(rawValue))
        } else {
            encoder.put(UInt8(0xff))
            encoder.put(rawValue)
        }
    }

    public func reportSize(to visitor: inout BinarySizeVisitor) {
        visitor.count(UInt8.self)
        switch rawValue {
        case 0xfd ... UInt64(UInt16.max):
            visitor.count(UInt16.self)
        case UInt64(UInt16.max) + 1 ... UInt64(UInt32.max):
            visitor.count(UInt32.self)
        case UInt64(UInt32.max) + 1 ... UInt64.max:
            visitor.count(UInt64.self)
        default: break
        }
    }
}
