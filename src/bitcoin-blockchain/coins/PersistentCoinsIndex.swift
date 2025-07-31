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
        env = try! Environment(at: URL(filePath: path.appending("coins").string), maxDBs: 1, pages: 380_000, options: [.noSubDir])
        try! env.createDB(byID)
    }

    let logger: Logger
    private let env: Environment

    var all: [Outpoint : UnspentOutput] { get {
        var unordered = [Outpoint : UnspentOutput]()
        do {
            try env.withTransaction(db: byID, options: .readOnly) { _, byID in
                try byID.withCursor(readOnly: true) { cursor in
                    var maybeKv = try cursor.getKeyValue()
                    while let kv = maybeKv {
                        let (outpointData, coinData) = kv
                        let outpoint = try Outpoint(outpointData)
                        let coin = try UnspentOutput(coinData)
                        unordered[outpoint] = coin
                        maybeKv = try cursor.getKeyValue(.next)
                    }
                }
            }
        } catch {
            return [ : ]
        }
        return unordered
    } }

    func get(_ outpoint: Outpoint) throws(CoinsError) -> UnspentOutput? {
        let result: UnspentOutput?
        do {
            result = try env.withTransaction(db: byID, options: .readOnly) { _, byID  throws(CoinsError) in
                try _get(outpoint, byID: byID)
            }
        } catch {
            switch error {
            case let .handlerIssue(nestedError):
                throw nestedError
            default:
                throw .databaseError(error)
            }
        }
        return result
    }

    func update(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint : UnspentOutput]) throws(CoinsError) -> [UnspentOutput?] {
        var removedCoins = [UnspentOutput?]()
        do {
            try env.withTransaction(db: byID) { _, byID throws(CoinsError) in
                for outpoint in outpointsToRemove {
                    guard let coin = try _get(outpoint, byID: byID) else {
                        removedCoins.append(nil)
                        continue // Some coins may be spends from within the block
                    }
                    removedCoins.append(coin)
                    let deleted: Bool
                    do {
                        deleted = try byID.delete(outpoint.data)
                    } catch {
                        throw CoinsError.databaseError(error)
                    }
                    if !deleted {
                        throw CoinsError.spentCoinNotFound
                    }
                }
                for (outpoint, coin) in coinsToAdd {
                    do {
                        try byID.put(coin.data, key: outpoint.data)
                    } catch {
                        throw CoinsError.databaseError(error)
                    }
                }
            }
        } catch {
            switch error {
            case let .handlerIssue(nestedError):
                throw nestedError
            default:
                throw .databaseError(error)
            }
        }
        return removedCoins
    }

    func add(_ coin: UnspentOutput, for outpoint: Outpoint) {
        try! env.withTransaction(db: byID) { _, byID in
            try byID.put(coin.data, key: outpoint.data)
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

    private func _get(_ outpoint: Outpoint, byID: borrowing LMDB.Database) throws(CoinsError) -> UnspentOutput? {
        let data: Data?
        do {
            data = try byID.get(outpoint.data)
        } catch {
            throw .databaseError(error)
        }
        guard let data else {
            return nil
        }
        do {
            return try UnspentOutput(data)
        } catch {
            throw .corruptedCoinData
        }
    }
