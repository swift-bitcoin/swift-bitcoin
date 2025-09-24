import CLMDB
import Foundation

extension Environment {

    package struct Options: OptionSet, Sendable {

        package let rawValue: Int32
        package init(rawValue: Int32) { self.rawValue = rawValue}

        package static let fixedMap = Self(rawValue: MDB_FIXEDMAP)
        package static let noSubDir = Self(rawValue: MDB_NOSUBDIR)
        package static let noSync = Self(rawValue: MDB_NOSYNC)
        package static let readOnly = Self(rawValue: MDB_RDONLY)
        package static let noMetaSync = Self(rawValue: MDB_NOMETASYNC)
        package static let writeMap = Self(rawValue: MDB_WRITEMAP)
        package static let mapAsync = Self(rawValue: MDB_MAPASYNC)
        package static let noTLS = Self(rawValue: MDB_NOTLS)
        package static let noLock = Self(rawValue: MDB_NOLOCK)
        package static let noReadahead = Self(rawValue: MDB_NORDAHEAD)
        package static let noMemoryInit = Self(rawValue: MDB_NOMEMINIT)

        var unsigned: UInt32 { .init(rawValue) }
    }
}
