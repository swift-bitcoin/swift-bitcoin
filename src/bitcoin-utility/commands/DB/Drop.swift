import ArgumentParser
import LMDB
import Foundation
import struct SystemPackage.FilePath
import _NIOFileSystem

struct Drop: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ""
    )

    @OptionGroup var parent: DB

    mutating func run() async throws {
        let path: FilePath
        if let p = parent.path {
            path = FilePath(p)
        } else {
            path = try await FileSystem.shared.homeDirectory.appending(".swift-bitcoin/data").appending("block-index")
        }
        var env = try! Environment(at: URL(filePath: path.string), maxDBs: 2, pages: 3_000, options: [.noSubDir])
        try! env.createDB(byID)
        try! env.withTransaction(db: .init(byHeightName, options: [.create, .integerKey, .duplicateSort, .duplicateFixed])) { _, _ in }
        try env.withTransaction(db: byID, byHeight) { tx, byID, byHeight in
            try byHeight.drop(delete: true)
            try byID.drop(delete: true)
        }
        env.drop()
    }
}
private let byIDName = "by-id"
private let byHeightName = "by-height"
private let byID = Database.Descriptor(byIDName)
private let byHeight = Database.Descriptor(byHeightName)
