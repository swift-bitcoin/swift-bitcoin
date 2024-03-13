import Foundation

/// The version of a ``BitcoinTransaction``.
///
/// Version 2 transactions enable use of relative lock times.
public struct TransactionVersion: Equatable, Comparable, Sendable {

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

    public static func < (lhs: TransactionVersion, rhs: TransactionVersion) -> Bool {
        lhs.versionValue < rhs.versionValue
    }

    /// Transaction version 1.
    public static let v1 = Self(1)

    /// BIP68 - Transaction version 2.
    public static let v2 = Self(2)
}
