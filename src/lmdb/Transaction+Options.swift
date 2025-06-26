import CLMDB
import Foundation

extension Transaction {

    package struct Options: OptionSet, Sendable {

        package let rawValue: Int32
        package init(rawValue: Int32) { self.rawValue = rawValue}

        package static let readOnly = Self(rawValue: MDB_RDONLY)

        var unsigned: UInt32 { .init(rawValue) }
    }
}
