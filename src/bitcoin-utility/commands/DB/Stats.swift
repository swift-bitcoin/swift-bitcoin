import ArgumentParser
import LMDB
import struct SystemPackage.FilePath
import Foundation

struct Stats: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ""
    )

    @OptionGroup var parent: DB

    mutating func run() async throws {
        let path = FilePath(parent.path)
        let env = try! Environment(at: URL(filePath: path.string), options: [.noSubDir, .readOnly])
//        try! env.createDB(byID)
//        try! env.withTransaction(db: .init(byHeightName, options: [.create, .integerKey, .duplicateSort, .duplicateFixed])) { _, _ in }

        let (byIDStats, byHeightStats) = try env.withTransaction(db: byID, byHeight, options: .readOnly) { tx, byID, byHeight in
            (try byID.stats, try byHeight.stats)
        }
        print("By-ID Entries: \(byIDStats.entries)")
        print("By-Height Entries: \(byHeightStats.entries)")
    }
}
private let byIDName = "by-id"
private let byHeightName = "by-height"
private let byID = Database.Descriptor(byIDName)
private let byHeight = Database.Descriptor(byHeightName)
