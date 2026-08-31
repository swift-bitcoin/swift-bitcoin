import Foundation
import BitcoinCrypto

public extension PartiallySignedTx {

    enum Version: Int, Equatable, Sendable, BinaryCodable {

        public init(from decoder: inout BinaryDecoder, format: Never?) throws(PartiallySignedTxError) {
            let value: UInt32
            do {
                value = try decoder.decode()
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
            counter.count(value)
        }

        public func encode(into encoder: inout BinaryEncoder, format: Never?) {
            encoder.encode(value)
        }
    }
}
