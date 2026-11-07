import BinaryParsing
import BitcoinBase
import Foundation
import LMDB
import Logging
import _NIOFileSystem

/// An index plus in-memory storage for coins.
actor PersistentCoinIndex: CoinIndex {
    enum Error: Swift.Error {
        case deletionIssue
    }

    init(path: FilePath, logger: Logger) throws {
        self.path = path.appending("coins")
        self.logger = logger

        let env = try initCoinIndexEnv(path: self.path)
        let byID = try env.openDatabase(named: "by-id")

        var coins = [Outpoint: UnspentOutput]()
        try env.read { txn in
            let cursor = try Cursor(txn, database: byID)

            var maybeKv = try cursor.first()
            while let kv = maybeKv {
                let outpoint = try kv.key(as: Outpoint.self)
                let coin = try kv.value(as: UnspentOutput.self)
                coins[outpoint] = coin
                maybeKv = try cursor.next()
            }
        }
        self.env = env
        self.byID = byID
        self.coins = coins
    }

    let path: FilePath
    private let logger: Logger
    private let env: Environment
    private let byID: Database
    private(set) var coins: [Outpoint: UnspentOutput]

    func get(_ outpoint: Outpoint) -> UnspentOutput? {
        coins[outpoint]
    }

    func update(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint: UnspentOutput]) throws(CoinsError)
        -> [UnspentOutput?]
    {
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
        try! updatePersistent(remove: removedOutpoints, add: coinsToAdd)
        return removedCoins
    }

    private func updatePersistent(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint: UnspentOutput])
        throws /*(CoinsError)*/
    {
        do {
            try env.write { txn /*throws(CoinsError)*/ in
                for outpoint in outpointsToRemove {
                    let deleted: Bool
                    do {
                        deleted = try txn.delete(forKey: outpoint, in: byID)
                        // deleted = try byID.delete(outpoint.data)
                    } catch {
                        throw CoinsError.databaseError(error)
                    }
                    if !deleted {
                        throw CoinsError.spentCoinNotFound
                    }
                }
                for (outpoint, coin) in coinsToAdd {
                    do {
                        try txn.put(coin, forKey: outpoint, in: byID)
                        // try byID.put(coin.data, key: outpoint.data)
                    } catch {
                        throw CoinsError.databaseError(error)
                    }
                }
            }
        } catch {
            //            switch error {
            //            case let .handlerIssue(nestedError):
            //                throw nestedError
            //            default:
            throw CoinsError.databaseError(error)
            //            }
        }
    }
}

package func initCoinIndexEnv(path: FilePath) throws -> Environment {
    try Environment(
        path: path.string,
        options: .noSubdirectory,
        maxDatabases: 1,
        mapSize: 400_000 * Int(getpagesize()) // , fileMode: 0x755 // S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH
    )
}

extension Outpoint: LMDBCodable {
    public init(lmdbBytes bytes: RawSpan) throws(LMDBDecodingError) {
        var input = ParserSpan.init(bytes)
        do {
            try self.init(parsing: &input)
        } catch {
            throw .init(Outpoint.self, byteCount: bytes.byteCount, reason: "Malformed")
        }
    }

    public var encodedByteCount: Int {
        binarySize
    }

    public func encode(into out: inout OutputRawSpan) {
        try! self.encode(into: &out, format: nil)
    }
}

extension UnspentOutput: LMDBCodable {
    public init(lmdbBytes bytes: RawSpan) throws(LMDBDecodingError) {
        var input = ParserSpan.init(bytes)
        do {
            try self.init(parsing: &input)
        } catch {
            throw .init(UnspentOutput.self, byteCount: bytes.byteCount, reason: "Malformed")
        }
    }

    public var encodedByteCount: Int {
        binarySize
    }

    public func encode(into out: inout OutputRawSpan) {
        try! self.encode(into: &out, format: nil)
    }
}
