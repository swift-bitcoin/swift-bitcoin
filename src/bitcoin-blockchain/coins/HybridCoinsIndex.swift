import LMDB
import _NIOFileSystem
import Foundation
import struct SystemPackage.FilePath
import Logging
import BitcoinBase

/// An index plus in-memory storage for coins.
actor HybridCoinsIndex: CoinsIndex {

    enum Error: Swift.Error {
        case deletionIssue
    }

    init(path: FilePath, logger: Logger) {
        self.path = path.appending("coins")
        self.logger = logger
        env = initEnv(path: self.path)

        var coins = [Outpoint : UnspentOutput]()
        do {
            try env.withTransaction(db: byID, options: .readOnly) { _, byID in
                try byID.withCursor(readOnly: true) { cursor in
                    var maybeKv = try cursor.getPair()
                    while let kv = maybeKv {
                        let (outpointData, coinData) = kv
                        let outpoint = try Outpoint(outpointData)
                        let coin = try UnspentOutput(coinData)
                        coins[outpoint] = coin
                        maybeKv = try cursor.getPair(.next)
                    }
                }
            }
        } catch {
            coins = [:] // TODO: Throw error
        }
        self.coins = coins
    }

    private let path: FilePath
    private let logger: Logger
    private var env: Environment!
    private var coins: [Outpoint: UnspentOutput]

    var all: [Outpoint : UnspentOutput] { coins }

    func get(_ outpoint: Outpoint) -> UnspentOutput? {
        coins[outpoint]
    }

    func update(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint : UnspentOutput]) throws(CoinsError) -> [UnspentOutput?] {
        var removedOutpoints = [Outpoint]()
        var removedCoins = [UnspentOutput?]()
        for outpoint in outpointsToRemove {
            guard let coin = coins[outpoint] else {
                removedCoins.append(nil)
                continue // Some coins may be spends from within the block
            }
            removedOutpoints.append(outpoint)
            removedCoins.append(coin)
            coins[outpoint] = nil
        }
        for (outpoint, coin) in coinsToAdd {
            coins[outpoint] = coin
        }
        try updatePersistent(remove: removedOutpoints, add: coinsToAdd)
        return removedCoins
    }

    private func updatePersistent(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint : UnspentOutput]) throws(CoinsError) {
        do {
            try env.withTransaction(db: byID) { _, byID throws(CoinsError) in
                for outpoint in outpointsToRemove {
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
    }

    func add(_ coin: UnspentOutput, for outpoint: Outpoint) {
        coins[outpoint] = coin
        addPersistent(coin, for: outpoint)
    }

    private func addPersistent(_ coin: UnspentOutput, for outpoint: Outpoint) {
        try! env.withTransaction(db: byID) { _, byID in
            try byID.put(coin.data, key: outpoint.data)
        }
    }

    func remove(_ outpoint: Outpoint) throws(Error) {
        coins[outpoint] = nil
        try removePersistent(outpoint)
    }

    private func removePersistent(_ outpoint: Outpoint) throws(Error) {
        do {
            try env.withTransaction(db: byID) { _, byID in
                try byID.delete(outpoint.data)
            }
        } catch {
            logger.error("Problem removing coin.")
            throw .deletionIssue
        }
    }

    func clear() async {
        coins = .init()
        await clearPersistent()
    }

    private func clearPersistent() async {
        env = nil // closes env

        // Removes folder
        let fs = FileSystem.shared
        do {
            try await fs.removeItem(at: path)
        } catch {
            logger.error("Issue removing block index directory: \(error.localizedDescription)")
            return // TODO: Probably throw here
        }

        env = initEnv(path: path)
    }
}

private let byID = Database.Descriptor("by-id")

private func initEnv(path: FilePath) -> Environment {
    let env = try! Environment(at: URL(filePath: path.string), maxDBs: 1, pages: 400_000, options: [.noSubDir])
    try! env.createDB(byID)
    return env
}
