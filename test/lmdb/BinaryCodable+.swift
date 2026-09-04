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

extension Bool: BinaryEncodable, @retroactive ExpressibleByParsing {

    public init(parsing input: inout ParserSpan) throws {
        let num = try UInt8(parsing: &input)
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

extension Int: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(Int64(parsingLittleEndian: &input)) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int.self, .littleEndian) }
}

extension Int8: BinaryEncodable, @retroactive ExpressibleByParsing {
    // public init(parsing input: inout ParserSpan) throws { try self.init(parsing: &input) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int8.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int8.self, .littleEndian) }
}

extension Int16: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(parsingLittleEndian: &input) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int16.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int16.self, .littleEndian) }
}

extension Int32: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(parsingLittleEndian: &input) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int32.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int32.self, .littleEndian) }
}

extension Int64: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(parsingLittleEndian: &input) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(Int64.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: Int64.self, .littleEndian) }
}

extension UInt: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(UInt64(parsingLittleEndian: &input)) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt.self, .littleEndian) }
}

extension UInt8: BinaryEncodable, @retroactive ExpressibleByParsing {
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt8.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self) }
}

extension UInt16: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(parsingLittleEndian: &input) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt16.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt16.self, .littleEndian) }
}

extension UInt32: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(parsingLittleEndian: &input) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt32.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt32.self, .littleEndian) }
}

extension UInt64: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws { try self.init(parsingLittleEndian: &input) }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt64.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self, as: UInt64.self, .littleEndian) }
}

extension Float: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        let tmp = try UInt32(parsingLittleEndian: &input)
        self.init(bitPattern: tmp)
    }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt32.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self.bitPattern, as: UInt32.self) }
}

extension Double: BinaryEncodable, @retroactive ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        let tmp = try UInt64(parsingLittleEndian: &input)
        self.init(bitPattern: tmp)
    }
    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) { counter.count(UInt64.self) }
    public func encode(into out: inout OutputRawSpan, format: Never?) throws { out.append(self.bitPattern, as: UInt64.self) }
}

extension String: BinaryEncodable, @retroactive ExpressibleByParsing {

    public init(parsing input: inout ParserSpan) throws {
        self.init(parsingUTF8: &input)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.countSize(data(using: .utf8)!.count)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(contentsOf: data(using: .utf8)!)
    }
}

extension Date: BinaryEncodable, @retroactive ExpressibleByParsing {

    public init(parsing input: inout ParserSpan) throws {
        let interval = try TimeInterval(parsing: &input)
        self.init(timeIntervalSince1970: interval)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.countSize(MemoryLayout<Double>.size)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(timeIntervalSince1970, as: Double.self)
    }
}
