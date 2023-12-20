import Foundation

/// Lock time value for a ``Transaction``. If less than 500,000,000 is interpreted as the minimum block height at which the transaction is unlocked. When equal or greater than 500,000,000 it represents the time (UNIX epoch) at which the transaction is unlocked. Use 0 to disable the time lock entirely.
public struct TransactionLocktime: Equatable {

    public init(_ locktimeValue: Int) {
        self.locktimeValue = locktimeValue
    }

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let value32 = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.init(Int(value32))
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

    var data: Data {
        withUnsafeBytes(of: rawValue) { Data($0) }
    }

    var rawValue: UInt32 { UInt32(locktimeValue) }

    public static let disabled = Self(0)
    public static let maxBlock = Self(minClock.locktimeValue - 1)
    public static let minClock = Self(500_000_000)
    static let size = MemoryLayout<UInt32>.size
}
