import Foundation
import CLMDB

package struct LMDBVersion: Sendable {
    package let major: Int
    package let minor: Int
    package let patch: Int
    package let versionString: String

    private init(major: Int, minor: Int, patch: Int, versionString: String) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.versionString = versionString
    }

    package static let current: LMDBVersion = {
        var major: Int32 = -1
        var minor: Int32 = -1
        var patch: Int32 = -1
        guard let versionCString = mdb_version(&major, &minor, &patch) else {
            return .init(major: Int(major), minor: Int(minor), patch: Int(patch), versionString: "")
        }
        let versionString = String(cString: versionCString)
        return .init(major: Int(major), minor: Int(minor), patch: Int(patch), versionString: versionString)
    }()
}
