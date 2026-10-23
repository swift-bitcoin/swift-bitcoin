import Foundation
import BinaryParsing
import BitcoinCrypto

/// BIP152
public struct SendCompactMessage: Equatable {

    init(highBandwidth: Bool = false, version: Int = 2) {
        self.highBandwidth = highBandwidth
        self.version = version
    }

    public let highBandwidth: Bool
    public let version: Int
}

extension SendCompactMessage: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        highBandwidth = try Int8(parsing: &input) != 0
        version = Int(try UInt64(parsingLittleEndian: &input))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt8.self)
        counter.count(UInt64.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(highBandwidth ? 1 : 0, as: UInt8.self)
        out.append(UInt64(version), as: UInt64.self, .littleEndian)
    }
}
