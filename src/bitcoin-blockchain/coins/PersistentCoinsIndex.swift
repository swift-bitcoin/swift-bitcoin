import LMDB
import SystemPackage
import Logging
import BitcoinBase

private let logger = Logger(label: "swift-bitcoin.coins-index")

/// An index plus on-disk LMDB storage for coins.
actor PersistentCoinsIndex: CoinsIndex {

    enum Error: Swift.Error {
        case deletionIssue
    }

    init(path: FilePath) {
        db = try! Database(environment: .init(path: path.appending("coins"), flags: [.noSubDir], maxDBs: 1), name: nil, flags: [.create])
    }

    private let db: Database!

    func add(_ coin: UnspentOutput, for outpoint: Outpoint) {
        try? db.put(coin.binaryData, forKey: outpoint.binaryData)
    }

    func get(_ outpoint: Outpoint) -> UnspentOutput? { // TODO: Probably should throw
        let data = try! db.get(outpoint.binaryData)
        if let data {
            return try! UnspentOutput(binaryData: data)
        } else {
            return nil
        }
    }

    func remove(_ outpoint: Outpoint) throws(Error) {
        do {
            try db.deleteValue(forKey: outpoint.binaryData)
        } catch {
            logger.error("Problem removing coin.")
            throw .deletionIssue
        }
    }
}
