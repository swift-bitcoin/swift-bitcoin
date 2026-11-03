import ArgumentParser
import LMDB
import Foundation
import _NIOFileSystem
import func BitcoinBlockchain.initBlockIndexEnv

struct Stats: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ""
    )

    @OptionGroup var parent: DB

    mutating func run() async throws {
        let path: FilePath
        if let p = parent.path {
            path = FilePath(p)
        } else {
            path = try await FileSystem.shared.homeDirectory.appending([".swift-bitcoin/data", "block-index"])
        }
        let env = try initBlockIndexEnv(path: path)
        let byID = try env.openDatabase(named: "by-id")
        let byHeight = try env.openDatabase(named: "by-height", options: [.duplicateSort, .duplicateFixed])
        let (byIDStats, byHeightStats) =  try env.read { txn in
            (try txn.statistics(for: byID), try txn.statistics(for: byHeight))
        }

        print("By-ID Entries: \(byIDStats.entries)")
        print("By-Height Entries: \(byHeightStats.entries)")
    }
}
