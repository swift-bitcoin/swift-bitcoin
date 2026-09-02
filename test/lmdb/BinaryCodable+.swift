import BitcoinCrypto
import BinaryParsing
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


extension Bool: BinaryCodable {

    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let num: UInt8 = try decoder.decode()
        if num == 0 {
            self = false
        } else {
            self = true
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt8.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(self ? 1 : 0)
    }
}

extension Int: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int.self, .littleEndian) }
}

extension Int8: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int8.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int8.self, .littleEndian) }
}

extension Int16: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int16.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int16.self, .littleEndian) }
}

extension Int32: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int32.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int32.self, .littleEndian) }
}

extension Int64: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int64.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int64.self, .littleEndian) }
}

extension UInt: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt.self, .littleEndian) }
}

extension UInt8: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt8.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self) }
}

extension UInt16: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt16.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt16.self, .littleEndian) }
}

extension UInt32: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt32.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt32.self, .littleEndian) }
}

extension UInt64: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt64.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt64.self, .littleEndian) }
}

extension Float: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Float.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Float.self) }
}

extension Double: BinaryCodable {
    // public init(from decoder: inout BinaryDecoder, format: Never?) throws { self = try decoder.decode() }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Double.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Double.self) }
}

extension String: BinaryCodable {

    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let data = try decoder.decode()
        guard let maybeSelf = Self(data: data, encoding: .utf8) else {
            throw BinaryDecodingError.limitExceeded
        }
        self = maybeSelf
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.countSize(data(using: .utf8)!.count)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(contentsOf: data(using: .utf8)!)
    }

    /*
    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(data(using: .utf8)!)
    }
    */
}

extension Date: BinaryCodable {

    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let interval: TimeInterval = try decoder.decode()
        self.init(timeIntervalSince1970: interval)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(TimeInterval.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(timeIntervalSince1970, as: Double.self)
    }

    /*
    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(timeIntervalSince1970)
    }
    */
}
