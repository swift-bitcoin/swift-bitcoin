import Foundation
import BinaryParsing
import BitcoinCrypto

public enum ProtocolVersion: Int, Sendable, Comparable {

    case unsupported = 70015, latest = 70016, future = 70017

    init(_ value: Int) {
        self = if value == Self.latest.rawValue {
            .latest
        } else if value >= Self.future.rawValue {
            .future
        } else {
            .unsupported
        }
    }

    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension ProtocolVersion: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        let value: UInt32 = try .init(parsingLittleEndian: &input)
        self.init(Int(value))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt32(rawValue), as: UInt32.self, .littleEndian)
    }
}
