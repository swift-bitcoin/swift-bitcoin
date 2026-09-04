import Foundation
import BinaryParsing

extension Array: BinaryCodable where Element: BinaryCodable {

    public enum ArrayBinaryFormat {
        case unprefixed
    }

    public typealias BinaryFormat = (arrayBinaryFormat: ArrayBinaryFormat?, elementBinaryFormat: Element.BinaryFormat?)

    public init(parsing input: inout ParserSpan, format: BinaryFormat?) throws {
        guard format?.arrayBinaryFormat == nil else {
            preconditionFailure("Cannot decode an unprefixed array.")
        }

        let count = try VarInt(parsing: &input)

        self.init()
        for _ in 0 ..< count.value {
            let element = try Element(parsing: &input, format: format?.elementBinaryFormat)
            append(element)
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        if format?.arrayBinaryFormat == nil {
            counter.count(VarInt(count))
        }
        for e in self {
            e.countBytes(into: &counter, format: format?.elementBinaryFormat)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws {
        if format?.arrayBinaryFormat == nil {
            try VarInt(count).encode(into: &out)
        }
        for e in self {
            try e.encode(into: &out, format: format?.elementBinaryFormat)
        }
    }
}
