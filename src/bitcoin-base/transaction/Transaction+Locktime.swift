import Foundation
import BitcoinCrypto

extension Transaction {

    /// Lock time value for a ``Transaction``. If less than 500,000,000 is interpreted as the minimum block height at which the transaction is unlocked. When equal or greater than 500,000,000 it represents the time (UNIX epoch) at which the transaction is unlocked. Use 0 to disable the time lock entirely.
    public struct Locktime: Equatable, Sendable {

        public init(_ locktimeValue: Int) {
            self.locktimeValue = locktimeValue
        }

        /// The numeric lock time value.
        public let locktimeValue: Int

        public var blockHeight: Int? {
            guard locktimeValue <= Self.maxBlock.locktimeValue else {
                return nil
            }
            return locktimeValue
        }

        public var secondsSince1970: Int? {
            guard locktimeValue >= Self.minClock.locktimeValue else {
                return nil
            }
            return locktimeValue
        }

        var rawValue: UInt32 { UInt32(locktimeValue) }

        public static let disabled = Self(0)
        public static let minBlock = Self(1)
        public static let maxBlock = Self(minClock.locktimeValue - 1)
        public static let minClock = Self(500_000_000)
        public static let maxClock = Self(1 << 31)
    }
}

/// Binary data extensions.
extension Transaction.Locktime: BinaryCodable {
    public init(from decoder: inout BinaryDecoder) throws {
        let rawValue: UInt32 = try decoder.decode()
        self.init(Int(rawValue))
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(UInt32(locktimeValue))
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(UInt32.self)
    }
}
