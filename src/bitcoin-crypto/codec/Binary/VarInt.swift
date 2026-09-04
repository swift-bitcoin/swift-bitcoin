import BinaryParsing

/// A Bitcoin protocol variable integer – sometimes referred to as compact integer.
///
/// The default behavior when working with `Array<BinaryCodable>` is to prefix all arrays with their count encoded a `VarInt`.
public struct VarInt: Equatable, Sendable {

    public init(_ value: Int) {
        rawValue = .init(value)
    }

    // TODO: Currently only for transport messges, evaluate if ok to lower the upper bount to just Int64.max for those values.
    package init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    package private(set) var rawValue: UInt64

    public var value: Int {
        get { Int(rawValue) }
        set { rawValue = .init(newValue) }
    }
}

extension VarInt: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {

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

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
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
