import Testing
import BinaryParsing
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
        let location = try createDir()
        defer { clearDir(location) }
        _ = try Environment(at: location)
    }

    @Test func createUnnamedDatabase() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)
        try env.createDB(nil)
    }

    @Test func hasKey() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)
        try env.createDB(nil)

        let value = "Hello world!".data(using: .utf8)!
        let keyWithValue = "hv1".data(using: .utf8)!
        let keyWithoutValue = "hv2".data(using: .utf8)!

        try env.withTransaction(db: nil) { tx, db in
            try db.put(value, key: keyWithValue)

            let hasValue1 = try db.get(keyWithValue) != nil
            let hasValue2 = try db.get(keyWithoutValue) != nil

            #expect(hasValue1, "A value has been set for this key. Result should be true.")
            #expect(!hasValue2, "No value has been set for this key. Result should be false.")
        }
    }

    @Test func putGet() throws {

        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)
        try env.createDB(nil)

        // Key generating sequence
        var seq = sequence(first: 0, next: { $0 + 1 })
        let nextKey = { "key-\(seq.next()!)" }

        try env.withTransaction(db: nil) { _, db in
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
    }

    @Test func getNonExistent() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)
        try env.createDB(nil)
        let value = try env.get("any-key".data(using: .utf8)!)
        #expect(value == nil)
    }

    @Test func count() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)

        let count = 10
        try env.withTransaction(db: .create(nil)) { _, db in
            for i in 0 ..< count {
                try db.put("value-\(i)".data(using: .utf8)!, key: "key-\(i)".data(using: .utf8)!)
            }
            #expect(try db.count == count)
        }
    }

    @Test func stats() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)

        let stats = try env.withTransaction(db: .create(nil)) { _, db in
            try db.put("value".data(using: .utf8)!, key: "key".data(using: .utf8)!)
            return try db.stats
        }
        let multiPlatformPageSize = Int32(Int(_SC_PAGESIZE)) // The double wrapping is necessary for Linux compatibility.
        #expect(stats.pageSize == UInt32(sysconf(multiPlatformPageSize)))
        #expect(stats.depth == 1)
        #expect(stats.branchPageCount == 0)
        #expect(stats.leafPageCount == 1)
        #expect(stats.overflowPageCount == 0)
    }

    @Test func emptyKey() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)

        try env.withTransaction(db: .create(nil)) { _, db in
            #expect(throws: Database.AccessError.self) {
                try db.put("test".data(using: .utf8)!, key: "".data(using: .utf8)!)
            }
            return ()
        }
    }

    @Test func delete() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)

        let key = "deleteTest".data(using: .utf8)!

        try env.withTransaction(db: .create(nil)) { _, db in

            // Put a value
            try db.put("Hello world!".data(using: .utf8)!, key: key)

            // Delete the value.
            try db.delete(key)

            // Get the value
            let retrievedData = try db.get(key)
            #expect(retrievedData == nil, "Value still present after delete.")
        }
    }

    @Test func dropDatabase() throws {
        // Open a new db, creating it in the process.
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)
        try env.createDB(nil)

        try env.withTransaction(db: nil) { _, db in
            // Close the db and drop it.
            // Drop the db and get rid of the reference, so that the handle is closed.
            try db.drop()
        }

        // Attempt to open a db with the same name. We aren't passing in the .create flag, so this action should fail, indicating that the db was dropped successfully.
        do {
            try env.withTransaction(db: nil) { _, _ in }
        } catch Transaction.InitError.databaseIssue {
            // The desired outcome is that the db is not found.
        }
    }

    @Test func emptyDatabase() throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)
        try env.createDB(nil)

        let key = "test".data(using: .utf8)!
        try env.withTransaction(db: nil) { _, db in
            // Put a value
            try db.put("Hello world!".data(using: .utf8)!, key: key)
            #expect(try db.count == 1)
        }

        try env.withTransaction(db: nil) { _, db in
            #expect(try db.count == 1)

            // Empty the db.
            try db.empty()
            #expect(try db.count == 0)
        }

        // Get the value. We want the result to be nil, because the db was emptied.
        try env.withTransaction(db: nil) { _, db in
            let retrievedData = try db.get(key)
            #expect(retrievedData == nil, "Value still present after db being emptied.")
            #expect(try db.count == 0)

        }
    }

    @Test func readOnlyDatabase() throws {
        let value = "value".data(using: .utf8)!
        let key = "test".data(using: .utf8)!

        // Open db and add a value
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)

        try env.withTransaction(db: .create(nil)) { _, db in
            try db.put(value, key: key)
        }
        // Open the db again as a read only db.
        try env.withTransaction(db: nil, options: .readOnly) { _, db in

            let fetchedValue = try #require(try db.get(key))
            #expect(fetchedValue == value)

            // Writing a value to a read-only db should fail.
            #expect(throws: (any Error).self) {
                try db.put("newValue".data(using: .utf8)!, key: key)
            }
        }
    }

    @Test func cursor() throws {

        let keys = ["A", "B", "C", "D"].map { $0.data(using: .utf8)! }
        let values = ["1", "2", "3", "4"].map {$0.data(using: .utf8)! }

        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location)


        try env.withTransaction(db: .create(nil)) { _, db in


            // Insert test data
            try zip(keys, values).forEach { try db.put($0.1, key: $0.0) }
        }
        try env.withTransaction(db: nil) { _, db in
            try db.withCursor { cursor in
                for i in try 0 ..< db.count {
                    let value = try cursor.get(i == 0 ? .first : .next)
                    #expect(value == values[i])
                }
                #expect(try cursor.get(.next) == nil)
                //let key = String(data: k, encoding: .utf8)!
            }
        }
    }
}

/// Inserts a value and reads it back, verifying that the two values match.
private func putGetValue<T>(value: T, key: String, in db: borrowing Database) throws where T: BinaryEncodable & ExpressibleByParsing & Equatable {
    let keyData = key.data(using: .utf8)!
    try db.put(value.data, key: keyData)
    let valueData2 = try #require(try db.get(keyData))
    #expect(value.data == valueData2)
    let fetchedValue = try valueData2.withParserSpan { input in
        try T(parsing: &input)
    }
    #expect(value == fetchedValue, "The returned value does not match the one that was set.")
}
