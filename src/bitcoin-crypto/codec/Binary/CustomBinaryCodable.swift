import Foundation

/// Encode and decode binary data with custom encoding.
///
/// Because the associated ``CustomBinaryEncodable/Encoding`` and ``CustomBinaryDecodable/Encoding`` share their identifier, these must be the same type.
///
/// If the Swift Language changes in the future to allow for different `Encoding` types to be defined, this protocol can also be declared as `protocol CustomBinaryCodable<Encoding>: CustomBinaryEncodable, CustomBinaryDecodable {}`.
///
public typealias CustomBinaryCodable = CustomBinaryEncodable & CustomBinaryDecodable

public protocol CustomBinaryEncodable: BinaryEncodable {

    // TODO: Eventually remove extension of `BinaryEncodable` and provide defaults for `var dataSize: Int { dataSize(encoding: nil) }` and `var data: Data { data(encoding: nil) }`.

    associatedtype Encoding

    func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Encoding?)
    func encode(to encoder: inout BinaryEncoder, encoding: Encoding?)
}

public extension CustomBinaryEncodable {

    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        encodingSize(&counter, encoding: nil)
    }

    func encode(to encoder: inout BinaryEncoder) {
        encode(to: &encoder, encoding: nil)
    }

    func dataSize(encoding: Encoding?) -> Int {
        var counter = BinaryEncodingSizeCounter()
        encodingSize(&counter, encoding: encoding)
        return counter.size
    }

    func data(encoding: Encoding?) -> Data {
        var counter = BinaryEncodingSizeCounter()
        encodingSize(&counter, encoding: encoding)
        var encoder = BinaryEncoder(counter)
        encode(to: &encoder, encoding: encoding)
        return encoder.data
    }
}

public protocol CustomBinaryDecodable: BinaryDecodable {
    associatedtype Encoding

    init(from decoder: inout BinaryDecoder, encoding: Encoding?) throws
}

public extension CustomBinaryDecodable {

    init(from decoder: inout BinaryDecoder) throws {
        try self.init(from: &decoder, encoding: nil)
    }

    init<D: DataProtocol>(_ data: D) throws {
        try self.init(data, encoding: nil)
    }

    init<D: DataProtocol>(_ data:D, encoding: Encoding?) throws {
        var decoder = BinaryDecoder(data)
        try self.init(from: &decoder, encoding: encoding)
    }
}
