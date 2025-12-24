import ArgumentParser
import LMDB
import struct SystemPackage.FilePath
import Foundation

struct Duplicate: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ""
    )

    @OptionGroup var parent: DB

    mutating func run() async throws {
        let path = FilePath(URL.homeDirectory.relativePath).appending(".swift-bitcoin/data").appending("coins")
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
