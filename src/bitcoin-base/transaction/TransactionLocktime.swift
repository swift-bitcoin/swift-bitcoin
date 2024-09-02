import Foundation

/// Lock time value for a ``BitcoinTransaction``. If less than 500,000,000 is interpreted as the minimum block height at which the transaction is unlocked. When equal or greater than 500,000,000 it represents the time (UNIX epoch) at which the transaction is unlocked. Use 0 to disable the time lock entirely.
public struct TransactionLocktime: Equatable, Sendable {

    public init(_ locktimeValue: Int) {
        self.locktimeValue = locktimeValue
    }

    /// The numeric lock time value.
    public let locktimeValue: Int

    var blockHeight: Int? {
        guard locktimeValue <= Self.maxBlock.locktimeValue else {
            return nil
        }
        return locktimeValue
    }

    var secondsSince1970: Int? {
        guard locktimeValue >= Self.minClock.locktimeValue else {
            return nil
        }
        return locktimeValue
    }

    var rawValue: UInt32 { UInt32(locktimeValue) }

    public static let disabled = Self(0)
    public static let maxBlock = Self(minClock.locktimeValue - 1)
    public static let minClock = Self(500_000_000)
}

/// Data extensions.
extension TransactionLocktime {

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let value32 = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.init(Int(value32))
    }

    var data: Data {
        Data(value: rawValue)
    }

    static let size = MemoryLayout<UInt32>.size
}
