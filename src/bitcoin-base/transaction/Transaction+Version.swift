import Foundation
import BitcoinCrypto

extension Transaction {
    /// The version of a ``Transaction``.
    ///
    /// Version 2 transactions enable use of relative lock times.
    public struct Version: Equatable, Comparable, Sendable {

        private init(_ versionValue: Int) {
            self.versionValue = versionValue
        }

        init(_ rawValue: UInt32) {
            self.init(Int(rawValue))
        }

        public let versionValue: Int

        var rawValue: UInt32 {
            UInt32(versionValue)
        }

        public static func < (lhs: Transaction.Version, rhs: Transaction.Version) -> Bool {
            lhs.versionValue < rhs.versionValue
        }

        /// Transaction version 0.
        ///
        /// Used in BIP325 (signet)
        package static let v0 = Self(0)

        /// Transaction version 1.
        public static let v1 = Self(1)

        /// BIP68 - Transaction version 2.
        public static let v2 = Self(2)

        /// BIP431 - Transaction version 3 (TRUC).
        public static let v3 = Self(3)

        public static let current = Self.v2
        public static let minStandard = Self.v1
        public static let maxStandard = Self.v3
    }
}

/// Binary data extensions.
extension Transaction.Version: BinaryCodable {
    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let rawValue: UInt32 = try decoder.decode()
        self.init(Int(rawValue))
    }

    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(UInt32(versionValue))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32.self)
    }
}

