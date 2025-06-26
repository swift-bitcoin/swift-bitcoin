import CLMDB

extension Database {

    package struct Options: OptionSet, Sendable {

        package let rawValue: Int32
        package init(rawValue: Int32) { self.rawValue = rawValue}

        package static let reverseKey = Self(rawValue: MDB_REVERSEKEY)
        package static let duplicateSort = Self(rawValue: MDB_DUPSORT)
        package static let integerKey = Self(rawValue: MDB_INTEGERKEY)
        package static let duplicateFixed = Self(rawValue: MDB_DUPFIXED)
        package static let integerDuplicate = Self(rawValue: MDB_INTEGERDUP)
        package static let reverseDuplicate = Self(rawValue: MDB_REVERSEDUP)
        package static let create = Self(rawValue: MDB_CREATE)

        var unsigned: UInt32 { .init(rawValue) }
    }
}
