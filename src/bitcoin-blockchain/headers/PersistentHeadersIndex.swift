import LMDB
import Foundation
import struct SystemPackage.FilePath

/// An index plus storage for headers.
actor PersistentHeadersIndex: HeadersIndex {

    init(path: FilePath) {
        env = try! Environment(at: URL(filePath: path.appending("headers").string), maxDBs: 2, options: [.noSubDir])
        try! env.createDB(byID)
        try! env.withTransaction(db: .init(byPositionName, options: [.create, .integerKey])) { _, _ in }
    }

    private let env: Environment

    private var position = 0

    var isEmpty: Bool {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            try byID.count == 0
        }
    }

    var first: Block? {
        try! env.withTransaction(db: byID, byPosition, options: .readOnly) { _, byID, byPosition in
            guard try byID.count > 0 else {
                return nil
            }
            guard let id = try byPosition.first else {
                fatalError()
            }
            let data = try byID.get(id)
            if let data {
                return try! Block(data)
            } else {
                return nil
            }
        }
    }

    var last: Block? {
        try! env.withTransaction(db: byID, byPosition, options: .readOnly) { _, byID, byPosition in
            guard try byID.count > 0 else {
                return nil
            }
            guard let id = try byPosition.last else {
                fatalError()
            }
            let data = try byID.get(id)
            if let data {
                return try! Block(data)
            } else {
                return nil
            }
        }
    }

    func add(_ header: Block) {
        try! env.withTransaction(db: byID, byPosition) { [position] _, byID, byPosition in
            try byID.put(header.data, key: header.id)
            try byPosition.put(header.id, key: position)
        }
        position += 1
    }

    func has(_ id: Block.ID) -> Bool {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            try byID.get(id) != nil
        }
    }

    func get(_ id: Block.ID) -> Block? { // TODO: Probably should throw
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            let data = try byID.get(id)
            if let data {
                return try! Block(data)
            } else {
                return nil
            }
        }
    }

    func removeFirst() {
        try! env.withTransaction(db: byID, byPosition) { _, byID, byPosition in
            guard try byID.count > 0 else {
                return
            }
            let firstID = try byPosition.first!
            try byPosition.removeFirst()
            guard try byID.delete(firstID) else {
                fatalError()
            }
        }
    }
}

private let byID = Database.Descriptor("by-id")
private let byPositionName = "by-position"
private let byPosition = Database.Descriptor(byPositionName)
