import Testing
import Foundation
import SystemPackage
import LMDB

struct CursorTests {

    @Test func getFirst() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }

        let key0 = "key0".data(using: .utf8)!
        let val0 = "val0".data(using: .utf8)!
        let key1 = "key1".data(using: .utf8)!
        let val1 = "val1".data(using: .utf8)!
        let key2 = "key2".data(using: .utf8)!
        let val2 = "val2".data(using: .utf8)!

        #expect(db.count == 0)
        let firsNil = try db.first
        let lastNil = try db.last
        #expect(firsNil == .none)
        #expect(lastNil == .none)


        try db.put(val0, forKey: key0)
        try db.put(val1, forKey: key1)
        try db.put(val2, forKey: key2)
        #expect(db.count == 3)

        let firstElem = try db.first
        #expect(firstElem == val0)
        let lastElem = try db.last
        #expect(lastElem == val2)
    }

    @Test func removeFirst() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }

        let key0 = "key0".data(using: .utf8)!
        let val0 = "val0".data(using: .utf8)!
        let key1 = "key1".data(using: .utf8)!
        let val1 = "val1".data(using: .utf8)!

        #expect(db.count == 0)
        try db.put(val0, forKey: key0)
        try db.put(val1, forKey: key1)
        #expect(db.count == 2)

        try db.removeFirst()
        #expect(db.count == 1)

        let gotVal1 = try db.get(key1)
        #expect(val1 == gotVal1)

        let existsVal0 = try db.exists(key: key0)
        #expect(!existsVal0)
    }
}

private func createDB(_ name: String?, path: FilePath? = .none, envFlags: Environment.Flags = [], dbFlags: Database.Flags = [.create]) throws -> Database {
    let fm = FileManager.default
    let envPath: FilePath
    if let path {
        envPath = path
    } else {
        let disambiguator = UInt.random(in: UInt.min ... UInt.max)
        let envDir = fm.temporaryDirectory.appendingPathComponent("\(disambiguator)")
        envPath = .init(envDir.path)
        try? fm.removeItem(atPath: envPath.string)
        try fm.createDirectory(atPath: envPath.string, withIntermediateDirectories: true)
    }
    let environment = try Environment(path: envPath, flags: envFlags, maxDBs: 32)
    return try environment.openDatabase(named: name, flags: dbFlags)
}

private func clearDB(_ db: Database) {
    let environment = db.environment
    try? db.drop()
    try? FileManager.default.removeItem(atPath: environment.path.string)
}
