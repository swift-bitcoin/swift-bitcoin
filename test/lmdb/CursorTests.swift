import Testing
import Foundation
import SystemPackage
import LMDB

struct CursorTests {

    /// Order is determined by integer key.
    @Test func getFirstWithIntegerKey() throws {
        let location = try createDir()
        defer { clearDir(location) }

        // Order is determined by integer key.
        let key0 = 0x01ff
        let val0 = "val0".data(using: .utf8)!
        let key1 = 0x0200
        let val1 = "val1".data(using: .utf8)!
        let key2 = 0x0300
        let val2 = "val2".data(using: .utf8)!

        let env = try Environment(at: location)
        try env.withTransaction(db: .init("integerKeys", options: [.create, .integerKey])) { tx, db in
            #expect(try db.count == 0)
            #expect(try db.first == nil)
            #expect(try db.last == nil)
            try db.put(val0, key: key0)
            try db.put(val1, key: key1)
            try db.put(val2, key: key2)
            #expect(try db.count == 3)
        }

        try env.withTransaction(db: "integerKeys", options: [.readOnly]) { tx, db in
            let val = try db.get(key2)
            #expect(val == val2)
            #expect(try db.first == val0)
            #expect(try db.last == val2)
        }

        try env.withTransaction(db: .create("regularKeys")) { tx, db in
            #expect(try db.count == 0)
            #expect(try db.first == nil)
            #expect(try db.last == nil)
            try db.put(val0, key: key0)
            try db.put(val1, key: key1)
            try db.put(val2, key: key2)
            #expect(try db.count == 3)
        }

        try env.withTransaction(db: "regularKeys", options: [.readOnly]) { tx, db in
            let val = try db.get(key2)
            #expect(val == val2)
            #expect(try db.first == val1)
            #expect(try db.last == val0)
        }
    }

    /// Order is lexicographical by key.
    @Test func getFirstLexicoraphic() throws {
        let location = try createDir()
        defer { clearDir(location) }

        let key0 = "key2".data(using: .utf8)!
        let val0 = "val2".data(using: .utf8)!
        let key1 = "key1".data(using: .utf8)!
        let val1 = "val1".data(using: .utf8)!
        let key2 = "key0".data(using: .utf8)!
        let val2 = "val0".data(using: .utf8)!

        let env = try Environment(at: location)
        try env.withTransaction(db: .init("test", options: [.create, .integerKey])) { tx, db in
            #expect(try db.count == 0)
            #expect(try db.first == nil)
            #expect(try db.last == nil)
            try db.put(val0, key: key0)
            try db.put(val1, key: key1)
            try db.put(val2, key: key2)
            #expect(try db.count == 3)
        }

        try env.withTransaction(db: "test", options: [.readOnly]) { tx, db in
            #expect(try db.count == 3)
            let val = try db.get(key1)
            #expect(val == val1)
            #expect(try db.first == val2)
            #expect(try db.last == val0)
        }
    }

    @Test func removeFirst() throws {

        let location = try createDir()
        defer { clearDir(location) }

        let key0 = "key0".data(using: .utf8)!
        let val0 = "val0".data(using: .utf8)!
        let key1 = "key1".data(using: .utf8)!
        let val1 = "val1".data(using: .utf8)!

        let env = try Environment(at: location)
        try env.withTransaction(db: .init("test", options: [.create, .integerKey])) { tx, db in
            #expect(try db.count == 0)
            try db.put(val0, key: key0)
            try db.put(val1, key: key1)
            #expect(try db.count == 2)
        }

        try env.withTransaction(db: "test") { tx, db in
            try db.removeFirst()
            #expect(try db.count == 1)
        }

        try env.withTransaction(db: "test", options: [.readOnly]) { tx, db in
            #expect(try db.count == 1)
            let val = try db.get(key0)
            #expect(val == nil)
        }
    }
}
