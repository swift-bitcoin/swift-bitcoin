import ArgumentParser
import LMDB
import Foundation
import _NIOFileSystem
import func BitcoinBlockchain.initCoinIndexEnv

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
            path = try await FileSystem.shared.homeDirectory.appending([".swift-bitcoin/data", "coins"])
        }
        let env = try initCoinIndexEnv(path: path)
        // let byID = try env.openDatabase(named: "by-id")
        var destinationPath = path
        destinationPath.extension = "copy"
        try env.copy(to: destinationPath.string, compact: true)
    }
}
