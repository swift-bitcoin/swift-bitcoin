import Foundation

public typealias BinaryCodable = BinaryDecodable & BinaryEncodable

public protocol BinaryEncodable {
    func encode(to encoder: inout BinaryEncoder)
    func reportSize(to visitor: inout BinaryEncoder.SizeVisitor)
}

public protocol BinaryDecodable {
    init(from decoder: inout BinaryDecoder) throws(BinaryDecoder.Error)
}

public extension BinaryEncodable {

    var binaryData: Data {
        var encoder = BinaryEncoder(count: binarySize)
        encode(to: &encoder)
        return encoder.data
    }

    var binarySize: Int {
        var visitor = BinaryEncoder.SizeVisitor()
        reportSize(to: &visitor)
        return visitor.size
    }
}

public extension BinaryDecodable {
    init<D: DataProtocol>(binaryData: D) throws(BinaryDecoder.Error) {
        var decoder = BinaryDecoder(binaryData)
        try self.init(from: &decoder)
    }
}
