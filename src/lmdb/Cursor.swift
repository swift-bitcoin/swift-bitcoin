import CLMDB
import Foundation

package struct Cursor: ~Copyable {

    init(txHandle: OpaquePointer, dbHandle: MDB_dbi) throws(InitError) {
        self.txHandle = txHandle
        self.dbHandle = dbHandle
        var handle = OpaquePointer?.none
        let status = mdb_cursor_open(txHandle, dbHandle, &handle)
        guard status == MDB_SUCCESS else {
            throw .initialization
        }
        self.handle = handle!
    }
    
    let txHandle: OpaquePointer
    let dbHandle: MDB_dbi
    let handle: OpaquePointer

    @discardableResult
    package func get(_ operation:  Operation = .first) throws(Database.AccessError) -> Data? {
        var keyVal = MDB_val()
        var dataVal = MDB_val()
        let operation: MDB_cursor_op = operation.value
        
        let status = mdb_cursor_get(handle, &keyVal, &dataVal, operation)
        if status == MDB_NOTFOUND {
            return nil
        }
        guard status == MDB_SUCCESS else {
            throw .getIssue
        }
        let data = Data(bytes: dataVal.mv_data, count: dataVal.mv_size)
        return data
    }

    package func delete() throws(Database.AccessError) {
        let status = mdb_cursor_del(handle, 0)
        guard status == MDB_SUCCESS else {
            throw .deleteIssue
        }
    }

    deinit {
        mdb_cursor_close(handle)
    }
}
