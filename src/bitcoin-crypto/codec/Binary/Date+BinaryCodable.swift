import Foundation

extension Date: BinaryCodable, CustomBinaryCodable {

    public typealias Encoding = Never

    public init(from decoder: inout BinaryDecoder, encoding: Encoding?) throws {
        let interval: TimeInterval = try decoder.decode()
        self.init(timeIntervalSince1970: interval)
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Encoding?) {
        encoder.encode(timeIntervalSince1970)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Encoding?) {
        counter.count(TimeInterval.self)
    }
}
