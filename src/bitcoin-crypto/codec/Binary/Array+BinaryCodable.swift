import Foundation
import BinaryParsing

extension Array: BinaryEncodable where Element: BinaryCodable {

    public enum ArrayBinaryFormat {
        case unprefixed
    }

    public typealias BinaryFormat = (arrayBinaryFormat: ArrayBinaryFormat?, elementBinaryFormat: Element.BinaryFormat?)

    public init(from decoder: inout BinaryDecoder, format: BinaryFormat?) throws {
        guard format?.arrayBinaryFormat == nil else {
            preconditionFailure("Cannot decode an unprefixed array.")
        }

        // let count: VarInt = try decoder.decode()
        let count: VarInt = try VarInt(decoder.peek(VarInt(.max).binarySize))
        try decoder.decode(count.binarySize)

        self.init()
        for _ in 0 ..< count.value {
            append(try decoder.decode(format: format?.elementBinaryFormat))
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

    /*
    public func encode(into encoder: inout BinaryEncoder, format: BinaryFormat?) {
        //encoder.encode(VarInt(count))
        encoder.encode(VarInt(count).data)
        for e in self {
            e.encode(into: &encoder, format: format)
        }
    }
    */
}
