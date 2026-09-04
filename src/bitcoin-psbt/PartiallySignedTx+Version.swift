import Foundation
import BinaryParsing
import BitcoinCrypto

public extension PartiallySignedTx {

    enum Version: Int, Equatable, Sendable, BinaryCodable {

        public init(parsing input: inout ParserSpan, format: Never?) throws(PartiallySignedTxError) {
            let value: UInt32
            do {
                value = try .init(parsingLittleEndian: &input)
            } catch {
                throw .invalidVersionEncoding
            }
            guard let version = Self(rawValue: Int(value)) else {
                throw .unsupportedVersion
            }
            self = version
        }

        case v0 = 0
        case v2 = 2

        private var value: UInt32 {
            UInt32(rawValue)
        }

        public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
            counter.count(UInt32.self)
        }

        public func encode(into out: inout OutputRawSpan, format: Never?) throws {
            out.append(value, as: UInt32.self, .littleEndian)
        }
    }
}
