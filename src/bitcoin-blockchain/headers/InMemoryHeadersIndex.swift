import LMDB
import SystemPackage

/// An index plus storage for headers.
actor DBHeadersIndex: HeadersIndex {

    init(path: FilePath) {
        db = try! Database(environment: .init(path: path.appending("headers"), flags: [.noSubDir], maxDBs: 2), name: "by-id", flags: [.create])
        byPositionDB = try! Database(environment: db.environment, name: "by-position", flags: [.create, .integerKey])
    }

    private let db: Database!
    private let byPositionDB: Database!

    private var position = 0

    var isEmpty: Bool {
        db.count == 0
    }

    var first: TxBlock? {
        guard !isEmpty else {
            return .none
        }
        guard let id = try! byPositionDB.first else {
            fatalError()
        }
        return get(id)
    }

    var last: TxBlock? {
        guard !isEmpty else {
            return .none
        }
        guard let id = try! byPositionDB.last else {
            fatalError()
        }
        return get(id)
    }

    func add(_ header: TxBlock) {
        try? db.put(header.binaryData, forKey: header.id)
        try? byPositionDB.put(header.id, key: position)
        position += 1
    }

    func has(_ id: BlockID) -> Bool {
        try! db.get(id) != .none
    }

    func get(_ id: BlockID) -> TxBlock? { // TODO: Probably should throw
        let data = try! db.get(id)
        if let data {
            return try! TxBlock(binaryData: data)
        } else {
            return .none
        }
    }

    func removeFirst() {
        if db.count > 0 {
            let firstID = try! byPositionDB.first
            try! byPositionDB.removeFirst()
            try! db.deleteValue(forKey: firstID!)
        }
    }
}
