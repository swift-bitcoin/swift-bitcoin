import LMDB
import SystemPackage
import Collections

/// An index plus storage for headers.
actor HeadersIndex {

    init(path: FilePath? = .none) {
        if let path {
            db = try! Database(environment: .init(path: path.appending("headers"), flags: [.noSubDir], maxDBs: 2), name: "by-id", flags: [.create])
            byPositionDB = try! Database(environment: db.environment, name: "by-position", flags: [.create, .integerKey])
        } else {
            db = .none
            byPositionDB = .none
        }
    }

    private let db: Database!
    private let byPositionDB: Database!
    private var headers = OrderedDictionary<BlockID, TxBlock>()

    private var position = 0

    var isEmpty: Bool {
        if db == nil {
            headers.isEmpty
        } else {
            db.count == 0
        }
    }

    var first: TxBlock? {
        guard !isEmpty else {
            return .none
        }
        if db == nil {
            return headers[headers.keys.first!]
        } else {
            guard let id = try! byPositionDB.first else {
                fatalError()
            }
            return get(id)
        }
    }

    var last: TxBlock? {
        guard !isEmpty else {
            return .none
        }
        if db == nil {
            return headers[headers.keys.last!]
        } else {
            guard let id = try! byPositionDB.last else {
                fatalError()
            }
            return get(id)
        }
    }

    func add(_ header: TxBlock) {
        if db == nil {
            headers[header.id] = header
        } else {
            try? db.put(header.binaryData, forKey: header.id)
            try? byPositionDB.put(header.id, key: position)
            position += 1
        }
    }

    func has(_ id: BlockID) -> Bool {
        if db == nil {
            headers[id] != .none
        } else {
            try! db.get(id) != .none
        }
    }

    func get(_ id: BlockID) -> TxBlock? { // TODO: Probably should throw
        if db == nil {
            return headers[id]
        } else {
            let data = try! db.get(id)
            if let data {
                return try! TxBlock(binaryData: data)
            } else {
                return .none
            }
        }
    }

    func removeFirst() {
        if db == nil {
            if headers.count > 0 {
                headers.removeFirst()
            }
        } else {
            if db.count > 0 {
                let firstID = try! byPositionDB.first
                try! byPositionDB.removeFirst()
                try! db.deleteValue(forKey: firstID!)
            }
        }
    }
}
