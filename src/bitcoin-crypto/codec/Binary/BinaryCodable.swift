import Foundation

public typealias BinaryCodable = BinaryDecodable & BinaryEncodable

public protocol BinaryEncodable {
    func encode(to encoder: inout BinaryEncoder)
    func reportSize(to visitor: inout BinarySizeVisitor)
}

public protocol BinaryDecodable {
    init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError)
}

public extension BinaryEncodable {

    var binaryData: Data {
        var encoder = BinaryEncoder(count: binarySize)
        encode(to: &encoder)
        return encoder.data
    }

    var binarySize: Int {
        var visitor = BinarySizeVisitor()
        reportSize(to: &visitor)
        return visitor.size
    }
}

public extension BinaryDecodable {
    init<D: DataProtocol>(binaryData: D) throws(BinaryDecodingError) {
        var decoder = BinaryDecoder(binaryData)
        try self.init(from: &decoder)
    }
}
