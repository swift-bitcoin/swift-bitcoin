import Foundation

extension Date: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let interval: TimeInterval = try decoder.decode()
        self.init(timeIntervalSince1970: interval)
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(timeIntervalSince1970)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(TimeInterval.self)
    }
}
