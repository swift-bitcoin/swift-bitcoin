import Foundation

/// The version of a ``Transaction``.
public struct Version: Equatable, Comparable {

    private init(_ versionValue: Int) {
        self.versionValue = versionValue
    }

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let rawValue = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        self.init(rawValue)
    }

    private init(_ rawValue: UInt32) {
        self.init(Int(rawValue))
    }

    public let versionValue: Int

    var data: Data {
        withUnsafeBytes(of: rawValue) { Data($0) }
    }

    var rawValue: UInt32 {
        UInt32(versionValue)
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        lhs.versionValue < rhs.versionValue
    }

    /// Transaction version 1.
    public static let v1 = Self(1)

    /// BIP68 - Transaction version 2.
    public static let v2 = Self(2)

    static let size = MemoryLayout<UInt32>.size
}
