import CLMDB
import Foundation

package struct Environment: ~Copyable {

    package init(at location: URL, maxDBs: Int = 32, maxReaders: Int = 126, mapSize: Int = 10485760, options: Options = []) throws(InitError) {

        var handle: OpaquePointer?
        var status = mdb_env_create(&handle)
        guard status == MDB_SUCCESS else {
            throw .createIssue
        }

        status = mdb_env_set_maxdbs(handle, MDB_dbi(maxDBs))
        guard status == MDB_SUCCESS else {
            throw .maxDatabasesIssue
        }

        // Set the maximum number of threads/reader slots for the environment.
        status = mdb_env_set_maxreaders(handle, UInt32(maxReaders))
        guard status == MDB_SUCCESS else {
            throw .maxReadersIssue
        }

        // Set the size of the memory map.
        status = mdb_env_set_mapsize(handle, mapSize)
        guard status == MDB_SUCCESS else {
            throw .mapSizeIssue
        }

        let fileMode: mode_t = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH

        status = mdb_env_open(handle, location.path.cString(using: .utf8), options.unsigned, fileMode)
        guard status == MDB_SUCCESS else {
            throw .openIssue
        }

        self.handle = handle!
    }

    private let handle: OpaquePointer

    package func createDB(_ db: Database.Descriptor) throws(Transaction.InitError) {
        var db = db
        db.options.insert(.create)
        try withTransaction(db: db) { _, _ in }
    }

    package func stats(for db: Database.Descriptor) throws(Transaction.InitError) -> Database.Statistics {
        try withTransaction(db: db) { _, db in
            try db.stats
        }
    }

    package func put(_ value: Data, key: Data, db: Database.Descriptor = nil, options: Database.PutOptions = [])  throws(Transaction.InitError) {
        try withTransaction(db: db) { tx, db in
            try db.put(value, key: key, options: options)
        }
    }

    package func get(_ key: Data, db: Database.Descriptor = nil) throws(Transaction.InitError) -> Data? {
        var value = Data?.none
        try withTransaction(db: db, options: [.readOnly]) { tx, db in
            value = try db.get(key)
        }
        return value
    }

    @discardableResult
    package func withTransaction<T>(db: Database.Descriptor, options: Transaction.Options = [], handler: @escaping (borrowing Transaction, borrowing Database) throws(any Error) -> T) throws(Transaction.InitError) -> T {
        try withTransaction(db: db, nil, options: options, handler: handler, handler2: nil)
    }

    @discardableResult
    package func withTransaction<T>(db: Database.Descriptor, _ anotherDB: Database.Descriptor, options: Transaction.Options = [], handler: @escaping (borrowing Transaction, borrowing Database, borrowing Database) throws(any Error) -> T) throws(Transaction.InitError) -> T {
        try withTransaction(db: db, anotherDB, options: options, handler: nil, handler2: handler)
    }

    private func withTransaction<T>(db: Database.Descriptor, _ anotherDB: Database.Descriptor?, options: Transaction.Options = [], handler: TransactionHandler<T>?, handler2: TransactionHandler2<T>?) throws(Transaction.InitError) -> T {
        let tx = try Transaction(env: handle, options: options)
        guard let db = tx.database(db) else {
            throw .databaseIssue
        }
        let db2: Database?
        if let anotherDB {
            guard let maybeDB2 = tx.database(anotherDB) else {
                throw .databaseIssue
            }
            db2 = consume maybeDB2
        } else {
            db2 = nil
        }
        let result: T
        do {
            result = if let db2, let handler2 {
                try handler2(tx, db, db2)
            } else if let handler {
                try handler(tx, db)
            } else {
                preconditionFailure()
            }
        } catch {
            tx.abort()
            throw .handlerIssue(error)
        }
        if options.contains(.readOnly) {
            tx.abort()
        } else {
            do {
                try tx.commit()
            } catch {
                throw .commitIssue
            }
        }
        return result
    }

    deinit {
        mdb_env_close(handle)
    }
}

private typealias TransactionHandler<T> = (borrowing Transaction, borrowing Database) throws(any Error) -> T

private typealias TransactionHandler2<T> = (borrowing Transaction, borrowing Database, borrowing Database) throws(any Error) -> T
