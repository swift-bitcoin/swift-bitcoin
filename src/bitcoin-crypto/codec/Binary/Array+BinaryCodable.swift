import Foundation

extension Array: BinaryCodable where Element: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let count: VarInt = try decoder.take()
        self.init()
        for _ in 0 ..< count.value {
            let e = try Element.init(from: &decoder)
            append(e)
        }
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.put(VarInt(count))
        for e in self {
            e.encode(to: &encoder)
        }
    }

    public func reportSize(to visitor: inout BinarySizeVisitor) {
        visitor.count(VarInt(count))
        for e in self {
            e.reportSize(to: &visitor)
        }
    }
}
