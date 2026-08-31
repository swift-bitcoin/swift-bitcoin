import Foundation

extension Date: BinaryCodable {

    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let interval: TimeInterval = try decoder.decode()
        self.init(timeIntervalSince1970: interval)
    }

    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(timeIntervalSince1970)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(TimeInterval.self)
    }
}
