import CLMDB
import Foundation

extension Environment {

    package struct CopyOptions: OptionSet, Sendable {

        package let rawValue: Int32
        package init(rawValue: Int32) { self.rawValue = rawValue}

        package static let compact = Self(rawValue: MDB_CP_COMPACT)

        var unsigned: UInt32 { .init(rawValue) }
    }
}
