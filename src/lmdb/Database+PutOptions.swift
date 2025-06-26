import CLMDB

extension Database {

    package struct PutOptions: OptionSet, Sendable {

        package let rawValue: Int32
        package init(rawValue: Int32) { self.rawValue = rawValue}

        package static let noDuplicateData = Self(rawValue: MDB_NODUPDATA)
        package static let noOverwrite = Self(rawValue: MDB_NOOVERWRITE)
        package static let reserve = Self(rawValue: MDB_RESERVE)
        package static let append = Self(rawValue: MDB_APPEND)
        package static let appendDuplicate = Self(rawValue: MDB_APPENDDUP)

        var unsigned: UInt32 { .init(rawValue) }
    }
}
