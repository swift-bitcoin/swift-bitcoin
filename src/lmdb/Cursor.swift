import Foundation
import CLMDB

public class Cursor {

    internal private(set) var handle: OpaquePointer?

    private let database: Database
    private let transaction: Transaction
    private var first = true

    /// Whether this cursor was used to delete an element. For some reason that messes up the deinit.
    private var deleted = false

    internal init(database: Database, transaction: Transaction) {
        self.database = database
        self.transaction = transaction
        mdb_cursor_open(transaction.handle, database.handle, &handle)
    }

    @discardableResult
    public func last() -> Element? {
        guard handle != nil, first else { return nil }

        var keyVal = MDB_val()
        var dataVal = MDB_val()
        let operation: MDB_cursor_op = MDB_LAST

        defer { first = false }

        let status = mdb_cursor_get(handle, &keyVal, &dataVal, operation)

        guard status == 0 else { return nil }

        let key = Data(bytes: keyVal.mv_data, count: keyVal.mv_size)
        let value = Data(bytes: dataVal.mv_data, count: dataVal.mv_size)
        return (key, value)
    }

    func delete() throws(LMDBError) {
        let status = mdb_cursor_del(handle, 0)
        defer { deleted = true }
        guard status == 0 else {
            throw LMDBError(returnCode: status)
        }
    }

    deinit {
        if let transactionHandle = mdb_cursor_txn(handle) {
            mdb_txn_commit(transactionHandle)
        }
        if !deleted {
            mdb_cursor_close(handle)
        }
    }
}

extension Cursor: IteratorProtocol {

    public typealias Element = (key: Data, value: Data)

    @discardableResult
    public func next() -> Element? {
        guard handle != nil else { return nil }

        var keyVal = MDB_val()
        var dataVal = MDB_val()
        let operation: MDB_cursor_op = first ? MDB_FIRST : MDB_NEXT

        defer { first = false }

        let status = mdb_cursor_get(handle, &keyVal, &dataVal, operation)

        guard status == 0 else { return nil }

        let key = Data(bytes: keyVal.mv_data, count: keyVal.mv_size)
        let value = Data(bytes: dataVal.mv_data, count: dataVal.mv_size)
        return (key, value)
    }
}
