import LMDB
import SystemPackage
import Logging
import BitcoinBase

private let logger = Logger(label: "swift-bitcoin.coins-index")

/// An index plus on-disk LMDB storage for coins.
actor DBCoinsIndex: CoinsIndex {

    enum Error: Swift.Error {
        case deletionIssue
    }

    init(path: FilePath) {
        db = try! Database(environment: .init(path: path.appending("coins"), flags: [.noSubDir], maxDBs: 1), name: .none, flags: [.create])
    }

    private let db: Database!

    func add(_ coin: UnspentOut, for outpoint: TxOutpoint) {
        try? db.put(coin.binaryData, forKey: outpoint.binaryData)
    }

    func get(_ outpoint: TxOutpoint) -> UnspentOut? { // TODO: Probably should throw
        let data = try! db.get(outpoint.binaryData)
        if let data {
            return try! UnspentOut(binaryData: data)
        } else {
            return .none
        }
    }

    func remove(_ outpoint: TxOutpoint) throws(Error) {
        do {
            try db.deleteValue(forKey: outpoint.binaryData)
        } catch {
            logger.error("Problem removing coin.")
            throw .deletionIssue
        }
    }
}
