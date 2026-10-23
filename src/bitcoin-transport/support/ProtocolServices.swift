import Foundation
import BinaryParsing
import BitcoinCrypto

public struct ProtocolServices: OptionSet, Sendable {
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public let rawValue: UInt64

    public static let network = Self(rawValue: 1 << 0)
    public static let witness = Self(rawValue: 1 << 3)

    public static let empty: Self = []
    public static let all: Self = [.network, .witness]
}

extension ProtocolServices: BinaryCodable {

    public enum ParseError: Error {
        /// Invalid network identifier value.
        case invalidNetworkIdentified(Int)
    }

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        self.init(rawValue: try UInt64(parsingLittleEndian: &input))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt64.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(rawValue, as: UInt64.self, .littleEndian)
    }
}
