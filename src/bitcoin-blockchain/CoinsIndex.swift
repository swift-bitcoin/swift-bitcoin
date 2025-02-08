import LMDB
import SystemPackage
import Collections
import Logging
import BitcoinBase

private let logger = Logger(label: "swift-bitcoin.coins-index")

/// An index plus storage for coins.
actor CoinsIndex {

    enum Error: Swift.Error {
        case deletionIssue
    }

    init(path: FilePath? = .none) {
        if let path {
            db = try! Database(environment: .init(path: path.appending("coins"), flags: [.noSubDir], maxDBs: 1), name: .none, flags: [.create])
        } else {
            db = .none
        }
    }

    private let db: Database!
    private var coins = OrderedDictionary<TxOutpoint, UnspentOut>()

    var isEmpty: Bool {
        if db == nil {
            coins.isEmpty
        } else {
            db.count == 0
        }
    }

    func add(_ coin: UnspentOut, for outpoint: TxOutpoint) {
        if db == nil {
            coins[outpoint] = coin
        } else {
            try? db.put(coin.binaryData, forKey: outpoint.binaryData)
        }
    }

    func remove(_ outpoint: TxOutpoint) throws(Error) {
        if db == nil {
            coins[outpoint] = .none
        } else {
            do {
                try db.deleteValue(forKey: outpoint.binaryData)
            } catch {
                logger.error("Problem removing coin.")
                throw .deletionIssue
            }
        }
    }

    func get(_ outpoint: TxOutpoint) -> UnspentOut? { // TODO: Probably should throw
        if db == nil {
            return coins[outpoint]
        } else {
            let data = try! db.get(outpoint.binaryData)
            if let data {
                return try! UnspentOut(binaryData: data)
            } else {
                return .none
            }
        }
    }
}
