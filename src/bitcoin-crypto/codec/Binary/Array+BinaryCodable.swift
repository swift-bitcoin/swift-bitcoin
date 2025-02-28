import Foundation

extension Array: BinaryCodable where Element: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws {
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

extension Array: CustomBinaryCodable where Element: CustomBinaryCodable {

    public init(from decoder: inout BinaryDecoder, encoding: Element.Encoding?) throws {
        let count: VarInt = try decoder.decode()
        self.init()
        for _ in 0 ..< count.value {
            append(try decoder.decode(encoding: encoding))
        }
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Element.Encoding?) {
        encoder.encode(VarInt(count))
        for e in self {
            e.encode(to: &encoder, encoding: encoding)
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Element.Encoding?) {
        counter.count(VarInt(count))
        for e in self {
            e.encodingSize(&counter, encoding: encoding)
        }
    }
}

/*
020000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff03011100ffffffff0200f2052a010000001976a914211f3a97b0046190b3c8d3af74d95c2e805cad3488ac0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000
 */
