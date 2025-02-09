import Foundation
import CLMDB

public struct LMDBVersion: Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    private init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static let current: LMDBVersion = {
        var major: Int32 = 0
        var minor: Int32 = 0
        var patch: Int32 = 0
        _ = mdb_version(&major, &minor, &patch)
        return LMDBVersion(major: Int(major), minor: Int(minor), patch: Int(patch))
    }()
}
