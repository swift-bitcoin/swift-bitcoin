/// A Bitcoin protocol variable integer – sometimes referred to as compact integer.
///
/// In many cases ``BinaryEncoder`` and ``BinaryDecoder`` can handle variable integer prefixes automatically via a `variable` boolean parameter like in ``BinaryEncoder/encode(_:variable:byteSwapped:)`` or ``BinaryDecoder/decode(variable:byteSwapped:)``.
/// The default behavior when working with `Array<BinaryCodable>` is to prefix all arrays with their count encoded a `VarInt`.
public struct VarInt: Equatable, Sendable, BinaryCodable {

    public init(_ value: Int) {
        rawValue = .init(value)
    }

    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let firstByte = try decoder.decode() as UInt8
        if firstByte < 0xfd {
            rawValue = UInt64(firstByte)
        } else if firstByte == 0xfd {
            let value = try decoder.decode() as UInt16
            rawValue = UInt64(value)
        } else if firstByte == 0xfe {
            let value = try decoder.decode() as UInt32
            rawValue = UInt64(value)
        } else {
            rawValue = try decoder.decode() as UInt64
        }
    }

    private var rawValue: UInt64

    public var value: Int {
        get { Int(rawValue) }
        set { rawValue = .init(newValue) }
    }

    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        if rawValue < 0xfd {
            encoder.encode(UInt8(rawValue))
        } else if rawValue <= UInt16.max {
            encoder.encode(UInt8(0xfd))
            encoder.encode(UInt16(rawValue))
        } else if rawValue <= UInt32.max {
            encoder.encode(UInt8(0xfe))
            encoder.encode(UInt32(rawValue))
        } else {
            encoder.encode(UInt8(0xff))
            encoder.encode(rawValue)
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt8.self)
        switch rawValue {
        case 0xfd ... UInt64(UInt16.max):
            counter.count(UInt16.self)
        case UInt64(UInt16.max) + 1 ... UInt64(UInt32.max):
            counter.count(UInt32.self)
        case UInt64(UInt32.max) + 1 ... UInt64.max:
            counter.count(UInt64.self)
        default: break
        }
    }
}

// Binary parsing

import BinaryParsing

extension VarInt: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {

        let firstByte = try UInt8(parsing: &input)
        if firstByte < 0xfd {
            rawValue = UInt64(firstByte)
        } else if firstByte == 0xfd {
            let value = try UInt16(parsingLittleEndian: &input)
            rawValue = UInt64(value)
        } else if firstByte == 0xfe {
            let value = try UInt32(parsingLittleEndian: &input)
            rawValue = UInt64(value)
        } else {
            rawValue = try UInt64(parsingLittleEndian: &input)
        }
    }
}

extension VarInt {
    public func encode(into out: inout OutputRawSpan) throws {
        if rawValue < 0xfd {
            out.append(UInt8(rawValue))
        } else if rawValue <= UInt16.max {
            out.append(UInt8(0xfd))
            out.append(UInt16(rawValue), as: UInt16.self, .littleEndian)
        } else if rawValue <= UInt32.max {
            out.append(UInt8(0xfe))
            out.append(UInt32(rawValue), as: UInt32.self, .littleEndian)
        } else {
            out.append(UInt8(0xff))
            out.append(rawValue, as: UInt64.self, .littleEndian)
        }
    }
}
