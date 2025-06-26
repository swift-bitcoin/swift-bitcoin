import CLMDB
import Foundation

package struct Database: ~Copyable {

    init?(_ db: Descriptor, tx: OpaquePointer) {
        var handle: MDB_dbi = 0
        let status = mdb_dbi_open(tx, db.name?.cString(using: .utf8), db.options.unsigned, &handle)
        guard status == MDB_SUCCESS else {
            return nil
        }
        self.txHandle = tx
        self.handle = handle
    }

    private let txHandle: OpaquePointer
    private let handle: MDB_dbi

    package func put(_ value: Data, key: Data, options: PutOptions = []) throws(AccessError) {
        var mutableKey = key
        do {
            try mutableKey.withUnsafeMutableBytes {
                var keyData = MDB_val(mv_size: $0.count, mv_data: $0.baseAddress)
                try put(value, key: &keyData, options: options)
            }
        } catch {
            throw error as! AccessError
        }
    }

    package func put(_ value: Data, key: Int, options: PutOptions = []) throws(AccessError) {
        var mutableKey = key
        var keyData = withUnsafeMutablePointer(to: &mutableKey) {
            MDB_val(mv_size: MemoryLayout<Int>.size, mv_data: $0)
        }
        return try put(value, key: &keyData, options: options)
    }

    private func put(_ value: Data, key: inout MDB_val, options: PutOptions = []) throws(AccessError) {
        var mutableValue = value
        let status = mutableValue.withUnsafeMutableBytes {
            var valueData = MDB_val(mv_size: $0.count, mv_data: $0.baseAddress)
            return mdb_put(txHandle, handle, &key, &valueData, options.unsigned)
        }
        guard status == MDB_SUCCESS else {
            throw .putIssue
        }
    }

    package func get(_ key: Data) throws(AccessError)  -> Data? {
        var mutableKey = key
        var data: Data?
        do {
            data = try mutableKey.withUnsafeMutableBytes {
                var keyData = MDB_val(mv_size: $0.count, mv_data: $0.baseAddress)
                return try get(&keyData)
            }
        } catch {
            throw error as! AccessError
        }
        return data
    }

    package func get(_ key: Int) throws(AccessError)  -> Data? {
        var mutableKey = key
        var keyData = withUnsafeMutablePointer(to: &mutableKey) {
            MDB_val(mv_size: MemoryLayout<Int>.size, mv_data: $0)
        }
        return try get(&keyData)
    }

    private func get(_ key: inout MDB_val) throws(AccessError)  -> Data? {
        // The database will manage the memory for the returned value.
        // http://104.237.133.194/doc/group__mdb.html#ga8bf10cd91d3f3a83a34d04ce6b07992d
        var dataVal = MDB_val()
        let status = mdb_get(txHandle, handle, &key, &dataVal)
        if status == MDB_NOTFOUND {
            return nil
        }
        guard status == MDB_SUCCESS else {
            throw .getIssue
        }
        let data = Data(bytes: dataVal.mv_data, count: dataVal.mv_size)
        return data
    }

    @discardableResult
    package func delete(_ key: Data) throws(AccessError)  -> Bool {
        var mutableKey = key
        var result: Bool
        do {
            result = try mutableKey.withUnsafeMutableBytes {
                var keyData = MDB_val(mv_size: $0.count, mv_data: $0.baseAddress)
                return try delete(&keyData)
            }
        } catch {
            throw error as! AccessError
        }
        return result
    }

    @discardableResult
    package func delete(_ key: Int) throws(AccessError)  -> Bool {
        var mutableKey = key
        var keyData = withUnsafeMutablePointer(to: &mutableKey) {
            MDB_val(mv_size: MemoryLayout<Int>.size, mv_data: $0)
        }
        return try delete(&keyData)
    }

    private func delete(_ key: inout MDB_val) throws(AccessError) -> Bool {
        let status = mdb_del(txHandle, handle, &key, nil)
        if status == MDB_NOTFOUND {
            return false
        }
        guard status == MDB_SUCCESS else {
            throw .deleteIssue
        }
        return true
    }

    package var first: Data? { get throws(Cursor.InitError) {
        try withCursor { try $0.get() }
    } }

    package var last: Data? { get throws(Cursor.InitError) {
        try withCursor { try $0.get(.last) }
    } }

    /// Empties the database, removing all key/value pairs.
    /// The database remains open after being emptied and can still be used.
    /// - throws: an error if operation fails. See `AccessError`.
    public func empty() throws(AccessError) {
        guard mdb_drop(txHandle, handle, 0) == MDB_SUCCESS else {
            throw .dropIssue
        }
    }

    /// Drops the database, deleting it (along with all its contents) from the environment.
    /// - warning: Dropping a database also closes it. You may no longer use the database after dropping it.
    /// - seealso: `empty()`
    /// - throws: an error if operation fails. See `AccessError`.
    public func drop() throws(AccessError) {
        guard mdb_drop(txHandle, handle, 0) == MDB_SUCCESS else {
            throw .dropIssue
        }
    }

    package func withCursor<T>(readOnly: Bool = false, handler: (borrowing Cursor) throws(Error) -> T) throws(Cursor.InitError) -> T {
        let cursor = try Cursor(txHandle: txHandle, dbHandle: handle)
        let result: T
        do {
            result = try handler(cursor)
        } catch {
            throw .handler(error)
        }
        return result
    }

    package func removeFirst() throws(Cursor.InitError) {
        try withCursor {
            try $0.get()
            try $0.delete()
        }
    }

    package var stats: Statistics { get throws(AccessError) {
        var stat = MDB_stat()
        let status = mdb_stat(txHandle, handle, &stat)
        guard status == MDB_SUCCESS else {
            throw .statisticsIssue
        }
        return .init(stat: stat)
    } }

    /// The number of entries contained in the database.
    package var count: Int { get throws(AccessError) {
        try stats.entries
    } }

    deinit {
        // Database is destroyed by transaction abort or the env
    }
}
