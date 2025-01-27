import Foundation

extension Array: BinaryCodable where Element: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let count: VarInt = try decoder.decode()
        self.init()
        for _ in 0 ..< count.value {
            append(try decoder.decode())
        }
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(VarInt(count))
        for e in self {
            e.encode(to: &encoder)
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(VarInt(count))
        for e in self {
            e.encodingSize(&counter)
        }
    }
}
