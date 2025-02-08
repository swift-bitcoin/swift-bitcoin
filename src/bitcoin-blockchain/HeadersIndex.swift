import LMDB
import SystemPackage
import Collections

/// An index plus storage for headers.
actor HeadersIndex {

    init(path: FilePath? = .none) {
        if let path {
            db = try! Database(environment: .init(path: path.appending("headers"), flags: [.noSubDir], maxDBs: 1), name: .none, flags: [.create])
        } else {
            db = .none
        }
    }

    private let db: Database!
    private var headers = OrderedDictionary<BlockID, TxBlock>()

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
            guard let data = try! db.first, let header = try? TxBlock(binaryData: data) else {
                fatalError()
            }
            return header
        }
    }

    var last: TxBlock? {
        guard !isEmpty else {
            return .none
        }
        if db == nil {
            return headers[headers.keys.last!]
        } else {
            guard let data = try! db.last, let header = try? TxBlock(binaryData: data) else {
                fatalError()
            }
            return header
        }
    }

    func add(_ header: TxBlock) {
        if db == nil {
            headers[header.id] = header
        } else {
            try? db.put(header.binaryData, forKey: header.id)
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
                try! db.removeFirst()
            }
        }
    }
}
