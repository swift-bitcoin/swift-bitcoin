import LMDB
import Foundation
import struct SystemPackage.FilePath
import Logging
import BitcoinBase

/// An index plus on-disk LMDB storage for coins.
actor PersistentCoinsIndex: CoinsIndex {

    enum Error: Swift.Error {
        case deletionIssue
    }

    init(path: FilePath, logger: Logger) {
        self.logger = logger
        env = try! Environment(at: URL(filePath: path.appending("coins").string), maxDBs: 1, options: [.noSubDir])
        try! env.createDB(byID)
    }

    let logger: Logger
    private let env: Environment

    func add(_ coin: UnspentOutput, for outpoint: Outpoint) {
        try! env.withTransaction(db: byID) { _, byID in
            try byID.put(coin.data, key: outpoint.data)
        }
    }

    func get(_ outpoint: Outpoint) -> UnspentOutput? { // TODO: Probably should throw
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            let data = try byID.get(outpoint.data)
            if let data {
                return try! UnspentOutput(data)
            } else {
                return nil
            }
        }
    }

    func remove(_ outpoint: Outpoint) throws(Error) {
        do {
            try env.withTransaction(db: byID) { _, byID in
                try byID.delete(outpoint.data)
            }
        } catch {
            logger.error("Problem removing coin.")
            throw .deletionIssue
        }
    }
}

private let byID = Database.Descriptor("by-id")
