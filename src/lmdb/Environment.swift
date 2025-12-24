import CLMDB
import Foundation

package struct Environment: ~Copyable {

    package init(at location: URL, maxDBs: Int = 32, maxReaders: Int = 126, pages: Int = 1_000, options: Options = []) throws(InitError) {

        let pageSize = Int(getpagesize()) // On Apple Sillicon macOS 16_384 bytes
        let mapSize = pages * pageSize

        var handle: OpaquePointer?
        var status = mdb_env_create(&handle)
        guard status == MDB_SUCCESS, let handle else {
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

        // Set the size of the memory map. Default mapSize: 10_485_760 bytes
        status = mdb_env_set_mapsize(handle, mapSize)
        guard status == MDB_SUCCESS else {
            throw .mapSizeIssue
        }

        let fileMode: mode_t = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH

        status = mdb_env_open(handle, location.path.cString(using: .utf8), options.unsigned, fileMode)
        guard status == MDB_SUCCESS else {
            throw .openIssue
        }

        self.handle = handle
    }

    private let handle: OpaquePointer

    func databases() throws -> [String] {
        try withTransaction(db: .init()) { _, db in
            try db.withCursor(readOnly: true) { cursor in
                var names = [String]()
                while let (key, _) = try cursor.getPair() {
                    guard let name = String(data: key, encoding: .utf8) else {
                        continue
                    }
                    names.append(name)
                }
                return names
            }
        }
    }

    func dropAll() throws {
        for db in try databases() {
            try withTransaction(db: .init(db)) { _, db in
                try db.drop(delete: true)
            }
        }
    }

    package mutating func drop() {
        guard mdb_env_sync(handle, 1) == MDB_SUCCESS else {
            preconditionFailure()
        }
    }

    public func copy(options: CopyOptions = []) throws(InitError) {
        var cPathPtr: UnsafePointer<CChar>? = nil
        guard mdb_env_get_path(handle, &cPathPtr) == MDB_SUCCESS, let cPathPtr else {
            throw .createIssue
        }
        let path = String(cString: cPathPtr) + "-2"
        guard mdb_env_copy2(handle, path.cString(using: .utf8), options.unsigned) == MDB_SUCCESS else {
            throw .createIssue
        }
    }

    package func createDB(_ db: Database.Descriptor) throws(Transaction.InitError<Never>) {
        var db = db
        db.options.insert(.create)
        try withTransaction(db: db) { _, _ throws(Never) in }
    }

    package func stats(for db: Database.Descriptor) throws(Transaction.InitError<Database.AccessError>) -> Database.Statistics {
        try withTransaction(db: db) { _, db throws(Database.AccessError) in
            try db.stats
        }
    }

    package func put(_ value: Data, key: Data, db: Database.Descriptor = nil, options: Database.PutOptions = [])  throws(Transaction.InitError<Database.AccessError>) {
        try withTransaction(db: db) { tx, db throws(Database.AccessError) in
            try db.put(value, key: key, options: options)
        }
    }

    package func get(_ key: Data, db: Database.Descriptor = nil) throws(Transaction.InitError<Database.AccessError>) -> Data? {
        var value = Data?.none
        try withTransaction(db: db, options: [.readOnly]) { tx, db throws(Database.AccessError) in
            value = try db.get(key)
        }
        return value
    }

    @discardableResult
    package func withTransaction<T, E: Error>(db: Database.Descriptor, options: Transaction.Options = [], handler: @escaping (borrowing Transaction, borrowing Database) throws(E) -> T) throws(Transaction.InitError<E>) -> T {
        try withTransaction(db: db, nil, options: options, handler: handler, handler2: nil)
    }

    @discardableResult
    package func withTransaction<T, E: Error>(db: Database.Descriptor, _ anotherDB: Database.Descriptor, options: Transaction.Options = [], handler: @escaping (borrowing Transaction, borrowing Database, borrowing Database) throws(E) -> T) throws(Transaction.InitError<E>) -> T {
        try withTransaction(db: db, anotherDB, options: options, handler: nil, handler2: handler)
    }

    private func withTransaction<T, E: Error>(db: Database.Descriptor, _ anotherDB: Database.Descriptor?, options: Transaction.Options = [], handler: TransactionHandler<T, E>?, handler2: TransactionHandler2<T, E>?) throws(Transaction.InitError<E>) -> T {
        let tx: Transaction
        do {
            tx = try Transaction(env: handle, options: options)
        } catch {
            throw .beginIssue
        }
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
        do throws(E) {
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

private typealias TransactionHandler<T, E: Error> = (borrowing Transaction, borrowing Database) throws(E) -> T

private typealias TransactionHandler2<T, E: Error> = (borrowing Transaction, borrowing Database, borrowing Database) throws(E) -> T
