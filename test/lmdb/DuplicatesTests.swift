import Foundation
import Testing
import LMDB

struct DuplicatesTests {

    @Test func duplicates() async throws {
        let location = try createDir()
        defer { clearDir(location) }
        let env = try Environment(at: location, maxDBs: 1, maxReaders: 1, options: [])
        let dbDesc = Database.Descriptor("test", options: [.create, .integerKey, .duplicateSort, .duplicateFixed])
        try env.withTransaction(db: dbDesc, options: []) { tx, db in
            try db.put(.init([5, 0, 5]), key: 3)
            try db.put(.init([2, 1, 0]), key: 3)
            try db.put(.init([6, 0, 0]), key: 3)
            try db.put(.init([3, 2, 1]), key: 9)
            try db.put(.init([1, 2, 3]), key: 9)
            try db.put(.init([6, 4, 2]), key: 9)
            try db.put(.init([8, 1]), key: 2)
            try db.put(.init([1, 1, 2, 2]), key: 4)
            try db.put(.init([0, 1, 2]), key: 6)
            try db.put(.init([2, 0, 1]), key: 6)
        }
        try env.withTransaction(db: dbDesc, options: [.readOnly]) { tx, db in

            // Access key with duplicates as if it where single value
            let data = try db.get(3)
            #expect(data == .init([2, 1, 0]))

            // Iterate through single and duplicate values
            try db.withCursor(readOnly: true) { cursor in
                let a = try cursor.get(.first)
                #expect(a == Data([8, 1]))
                let b = try cursor.get(.next)
                #expect(b == Data([2, 1, 0]))
                let c = try cursor.get(.nextDup)
                #expect(c == Data([5, 0, 5]))
                let d = try cursor.get(.nextDup)
                #expect(d == Data([6, 0, 0]))
                let e = try cursor.get(.next)
                #expect(e == Data([1, 1, 2, 2]))

                // Reset the cursor to key 3
                try cursor.set(key: 3)

                // Get all multiple values at once
                let bcd = try cursor.get(.getMultiple)
                #expect(bcd == Data([2, 1, 0, 5, 0, 5, 6, 0, 0]))

                let kvFirst = try #require(try cursor.getPair(.first))
                #expect(kvFirst == (.init([2, 0, 0, 0, 0, 0, 0, 0]), .init([8, 1])))

                let kvLast = try #require(try cursor.getPair(.last))
                #expect(kvLast == (.init([9, 0, 0, 0, 0, 0, 0, 0]), .init([6, 4, 2])))

                let lastFirst = try cursor.get(.firstDup)
                #expect(lastFirst == Data([1, 2, 3]))

                let everyLast = try cursor.get(.getMultiple)
                #expect(everyLast == Data([1, 2, 3, 3, 2, 1, 6, 4, 2]))

                let last3 = try cursor.get(.last)
                #expect(last3 == Data([6, 4, 2]))

                let last2 = try cursor.get(.prevDup)
                #expect(last2 == Data([3, 2, 1]))

                let last1 = try cursor.get(.prevDup)
                #expect(last1 == Data([1, 2, 3]))

                let last0 = try cursor.get(.prevDup)
                #expect(last0 == nil)

                let secondLast2 = try cursor.get(.prevNodup)
                #expect(secondLast2 == .init([2, 0, 1]))

                let secondLast1 = try cursor.get(.prevDup)
                #expect(secondLast1 == Data([0, 1, 2]))

                // Reset the cursor to key 3
                try cursor.set(key: 3)

                // Get all multiple values at once
                let bb = try cursor.get(.firstDup)
                #expect(bb == Data([2, 1, 0]))
            }
        }
    }
}
