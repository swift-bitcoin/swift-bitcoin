import BitcoinCrypto
import Foundation

func createDir() throws -> URL {
    let fm = FileManager.default
    let disambiguator = UInt.random(in: UInt.min ... UInt.max)
    let location = fm.temporaryDirectory.appendingPathComponent("\(disambiguator)")
    try? fm.removeItem(atPath: location.path)
    try fm.createDirectory(atPath: location.path, withIntermediateDirectories: true)
    return location
}

func clearDir(_ location: URL) {
    try? FileManager.default.removeItem(atPath: location.path)
}

extension String: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws {
        let data = try decoder.decode()
        guard let maybeSelf = Self(data: data, encoding: .utf8) else {
            throw BinaryDecodingError.limitExceeded
        }
        self = maybeSelf
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(data(using: .utf8)!)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.countSize(data(using: .utf8)!.count)
    }
}
