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

    package func set(key: Data, _ operation:  Operation = .set) throws(Database.AccessError) {
        var mutableKey = key
        var dataVal = MDB_val()
        let operation: MDB_cursor_op = operation.value

        do {
            try mutableKey.withUnsafeMutableBytes { [handle] buffer in
                var keyVal = MDB_val(mv_size: buffer.count, mv_data: buffer.baseAddress)
                let status = mdb_cursor_get(handle, &keyVal, &dataVal, operation)
                guard status == MDB_SUCCESS else {
                    throw Database.AccessError.getIssue
                }
            }
        } catch let error as Database.AccessError {
            throw error
        } catch { fatalError() }
    }

    package func set(key: Int, _ operation:  Operation = .set) throws(Database.AccessError) {
        var mutableKey = key
        var keyVal = withUnsafeMutablePointer(to: &mutableKey) {
            MDB_val(mv_size: MemoryLayout<Int>.size, mv_data: $0)
        }
        var dataVal = MDB_val()
        let operation: MDB_cursor_op = operation.value

        let status = mdb_cursor_get(handle, &keyVal, &dataVal, operation)
        guard status == MDB_SUCCESS else {
            throw .getIssue
        }
    }

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

    package func getPair(_ operation:  Operation = .first) throws(Database.AccessError) -> (Data, Data)? {
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
        let keyData = Data(bytes: keyVal.mv_data, count: keyVal.mv_size)
        let valueData = Data(bytes: dataVal.mv_data, count: dataVal.mv_size)
        return (keyData, valueData)
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
