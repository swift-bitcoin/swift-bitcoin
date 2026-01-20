import ArgumentParser
import LMDB
import Foundation
import _NIOFileSystem

struct Duplicate: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ""
    )

    @OptionGroup var parent: DB

    mutating func run() async throws {
        let path: FilePath
        if let p = parent.path {
            path = FilePath(p)
        } else {
            path = try await FileSystem.shared.homeDirectory.appending(".swift-bitcoin/data").appending("coins")
        }
        let env = try! Environment(at: URL(filePath: path.string), maxDBs: 2, pages: 3_000, options: [.noSubDir])
        //try! env.createDB(byID)
        //try! env.withTransaction(db: .init(byHeightName, options: [.create, .integerKey, .duplicateSort, .duplicateFixed])) { _, _ in }
        try env.copy(options: .compact)
    }
}
private let byIDName = "by-id"
private let byHeightName = "by-height"
private let byID = Database.Descriptor(byIDName)
private let byHeight = Database.Descriptor(byHeightName)
