import Foundation

/// Lock time value for a ``Transaction``. If less than 500,000,000 is interpreted as the minimum block height at which the transaction is unlocked. When equal or greater than 500,000,000 it represents the time (UNIX epoch) at which the transaction is unlocked. Use 0 to disable the time lock entirely.
public struct Locktime: Equatable {

    public init(_ locktimeValue: Int) {
        self.locktimeValue = locktimeValue
    }

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let value32 = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.init(value32)
    }

    private init(_ rawValue: UInt32) {
        self.init(Int(rawValue))
    }

    /// The numeric lock time value.
    public let locktimeValue: Int

    var data: Data {
        withUnsafeBytes(of: rawValue) { Data($0) }
    }

    var rawValue: UInt32 { UInt32(locktimeValue) }

    static let size = MemoryLayout<UInt32>.size
}
