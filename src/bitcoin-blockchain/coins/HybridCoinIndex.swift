import LMDB
import _NIOFileSystem
import Foundation
import struct SystemPackage.FilePath
import Logging
import BitcoinBase

/// An index plus in-memory storage for coins.
actor HybridCoinIndex: CoinIndex {

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
        _coins = coins
    }

    private let path: FilePath
    private let logger: Logger
    private var env: Environment!
    private var _coins: [Outpoint: UnspentOutput]

    var coins: [Outpoint : UnspentOutput] { _coins }

    func get(_ outpoint: Outpoint) -> UnspentOutput? {
        _coins[outpoint]
    }

    func update(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint : UnspentOutput]) throws(CoinsError) -> [UnspentOutput?] {
        var removedOutpoints = [Outpoint]()
        var removedCoins = [UnspentOutput?]()
        for outpoint in outpointsToRemove {
            guard let coin = _coins[outpoint] else {
                removedCoins.append(nil)
                continue // Some coins may be spends from within the block
            }
            removedOutpoints.append(outpoint)
            removedCoins.append(coin)
            _coins[outpoint] = nil
        }
        for (outpoint, coin) in coinsToAdd {
            _coins[outpoint] = coin
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

    func clear() async {
        _coins = .init()
        await clearPersistent()
    }

    private func clearPersistent() async {
        env = nil // closes env

        // Removes directory
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
