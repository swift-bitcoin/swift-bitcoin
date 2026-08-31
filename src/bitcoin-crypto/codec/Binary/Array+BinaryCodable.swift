import Foundation

extension Array: BinaryCodable where Element: BinaryCodable {

    public init(from decoder: inout BinaryDecoder, format: Element.BinaryFormat?) throws {
        let count: VarInt = try decoder.decode()
        self.init()
        for _ in 0 ..< count.value {
            append(try decoder.decode(format: format))
        }
    }

    public func encode(into encoder: inout BinaryEncoder, format: Element.BinaryFormat?) {
        encoder.encode(VarInt(count))
        for e in self {
            e.encode(into: &encoder, format: format)
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Element.BinaryFormat?) {
        counter.count(VarInt(count))
        for e in self {
            e.countBytes(into: &counter, format: format)
        }
    }
}
