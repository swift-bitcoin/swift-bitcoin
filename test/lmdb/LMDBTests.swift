import Testing
import BitcoinCrypto
import SystemPackage
import Foundation
import LMDB

struct LMDBTests {

    @Test func getLMDBVersion() throws {
        #expect(
            [LMDBVersion.current.major, LMDBVersion.current.minor, LMDBVersion.current.patch] !=
            [0, 0, 0]
        )
    }

    @Test func createEnvironment() throws {
        let fm = FileManager.default

        let disambiguator = UInt.random(in: UInt.min ... UInt.max)
        let envDir = fm.temporaryDirectory.appendingPathComponent("\(disambiguator)")

        try? fm.removeItem(atPath: envDir.path)
        try fm.createDirectory(at: envDir, withIntermediateDirectories: true)

        _ = try Environment(path: .init(envDir.path), flags: [], maxDBs: 32, maxReaders: 126, mapSize: 10485760)
        try fm.removeItem(atPath: envDir.path)
    }

    @Test func createUnnamedDatabase() throws {
        let db = try createDB(nil)
        clearDB(db)
    }

    @Test func hasKey() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }

        let value = "Hello world!"
        let keyWithValue = "hv1"
        let keyWithoutValue = "hv2"

        try db.put(value.data(using: .utf8)!, forKey: keyWithValue.data(using: .utf8)!)

        let hasValue1 = try db.exists(key: keyWithValue.data(using: .utf8)!)
        let hasValue2 = try db.exists(key: keyWithoutValue.data(using: .utf8)!)

        #expect(hasValue1, "A value has been set for this key. Result should be true.")
        #expect(!hasValue2, "No value has been set for this key. Result should be false.")
    }

    @Test func putGet() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }

        // Key generating sequence
        var seq = sequence(first: 0, next: { $0 + 1 })
        let nextKey = { "key-\(seq.next()!)" }

        // Boolean
        try putGetValue(value: true, key: nextKey(), in: db)
        try putGetValue(value: false, key: nextKey(), in: db)

        // String
        try putGetValue(value: "ÆØÅ", key: nextKey(), in: db)
        try putGetValue(value: "Hello world! 👋🏼", key: nextKey(), in: db)

        // Date
        try putGetValue(value: Date.distantFuture, key: nextKey(), in: db)

        // Integers
        try putGetValue(value: Int.max, key: nextKey(), in: db)
        try putGetValue(value: Int8.max, key: nextKey(), in: db)
        try putGetValue(value: Int16.max, key: nextKey(), in: db)
        try putGetValue(value: Int32.max, key: nextKey(), in: db)
        try putGetValue(value: Int64.max, key: nextKey(), in: db)

        try putGetValue(value: UInt.max, key: nextKey(), in: db)
        try putGetValue(value: UInt8.max, key: nextKey(), in: db)
        try putGetValue(value: UInt16.max, key: nextKey(), in: db)
        try putGetValue(value: UInt32.max, key: nextKey(), in: db)
        try putGetValue(value: UInt64.max, key: nextKey(), in: db)

        // Floats
        try putGetValue(value: Float.leastNormalMagnitude, key: nextKey(), in: db)
        try putGetValue(value: Double.leastNormalMagnitude, key: nextKey(), in: db)

    }

    @Test func getNonExistant() throws {
        let db = try createDB(#function)
        defer { clearDB(db) }
        let value = try db.get("any-key".data(using: .utf8)!)
        #expect(value == nil)
    }

    @Test func count() throws {
        let db = try createDB(#function)
        defer { clearDB(db) }

        let count = 10
        for i in 0 ..< count {
            try db.put("value-\(i)".data(using: .utf8)!, forKey: "key-\(i)".data(using: .utf8)!)
        }
        #expect(count == db.count)
    }

    @Test func stats() throws {
        let db = try createDB(#function)
        defer { clearDB(db) }

        try db.put("value".data(using: .utf8)!, forKey: "key".data(using: .utf8)!)
        let stats = db.stats
        let multiPlatformPageSize = Int32(Int(_SC_PAGESIZE)) // The double wrapping is necessary for Linux compatibility.
        #expect(stats.pageSize == UInt32(sysconf(multiPlatformPageSize)))
        #expect(stats.depth == 1)
        #expect(stats.branchPageCount == 0)
        #expect(stats.leafPageCount == 1)
        #expect(stats.overflowPageCount == 0)
    }

    @Test func emptyKey() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }

        #expect(throws: (any Error).self) {
            try db.put("test".data(using: .utf8)!, forKey: "".data(using: .utf8)!)
        }

    }

    @Test func delete() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }
        let key = "deleteTest"

        // Put a value
        try db.put("Hello world!".data(using: .utf8)!, forKey: key.data(using: .utf8)!)

        // Delete the value.
        try db.deleteValue(forKey: key.data(using: .utf8)!)

        // Get the value
        let retrievedData = try db.get(key.data(using: .utf8)!)
        #expect(retrievedData == nil, "Value still present after delete.")
    }

    @Test func dropDatabase() throws {

        // Open a new db, creating it in the process.
        var db: Database! = try createDB(#function)
        let environment = db.environment

        // Close the db and drop it.
        // Drop the db and get rid of the reference, so that the handle is closed.
        try db.drop()
        db = nil

        // Attempt to open a db with the same name. We aren't passing in the .create flag, so this action should fail, indicating that the db was dropped successfully.
        do {
            db = try environment.openDatabase(named: #function)
        } catch LMDBError.notFound {
            // The desired outcome is that the db is not found.
        }
    }

    @Test func emptyDatabase() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }

        let key = "test"
        // Put a value
        try db.put("Hello world!".data(using: .utf8)!, forKey: key.data(using: .utf8)!)

        // Empty the db.
        try db.empty()

        // Get the value. We want the result to be nil, because the db was emptied.
        let retrievedData = try db.get(key.data(using: .utf8)!)
        #expect(retrievedData == nil, "Value still present after db being emptied.")
    }

    @Test func readOnlyDatabase() throws {

        let dbName = #function
        let value = "value"
        let key = "test"

        var envPath = FilePath?.none
        // Open db and add a value
        var db: Database! = try createDB(dbName)
        envPath = db.environment.path
        try db.put(value.data(using: .utf8)!, forKey: key.data(using: .utf8)!)
        db = nil

        // Open the db again as a read only db.
        let readOnlyDB = try createDB(dbName, path: envPath, envFlags: [.readOnly])
        defer { clearDB(readOnlyDB) }

        let fetchedData = try #require(try readOnlyDB.get(key.data(using: .utf8)!))
        let fetchedValue = String(data: fetchedData, encoding: .utf8)!
        #expect(fetchedValue == value)

        // Writing a value to a read-only db should fail.
        #expect(throws: (any Error).self) {
            try readOnlyDB.put("newValue".data(using: .utf8)!, forKey: key.data(using: .utf8)!)
        }
    }

    @Test func cursor() throws {

        let db = try createDB(#function)
        defer { clearDB(db) }

        let values = [
            "A": "1",
            "B": "2",
            "C": "3",
            "D": "4"
        ]

        // Insert test data
        try values.forEach { try db.put($0.1.data(using: .utf8)!, forKey: $0.0.data(using: .utf8)!) }

        for (k, v) in db {
            let key = String(data: k, encoding: .utf8)!
            let value = String(data: v, encoding: .utf8)!
            #expect(values[key] == value)
        }
    }
}

private func createDB(_ name: String?, path: FilePath? = nil, envFlags: Environment.Flags = [], dbFlags: Database.Flags = [.create]) throws -> Database {
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

/// Inserts a value and reads it back, verifying that the two values match.
private func putGetValue<T>(value: T, key: String, in db: Database) throws where T: BinaryCodable & Equatable {
    try db.put(value.data, forKey: key.data(using: .utf8)!)
    let value2 = try db.get(key.data(using: .utf8)!)
    let fetchedValue = try T(value2!)
    #expect(value == fetchedValue, "The returned value does not match the one that was set.")
}
