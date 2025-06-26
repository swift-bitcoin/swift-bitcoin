import CLMDB

package struct Transaction: ~Copyable {

    init(env: OpaquePointer, options: Options = []) throws(InitError) {
        var handle = OpaquePointer?.none
        let status = mdb_txn_begin(env, nil, options.unsigned, &handle)
        guard status == MDB_SUCCESS else {
            throw .beginIssue
        }
        self.handle = handle!
    }

    private let handle: OpaquePointer

    package func commit() throws(CommitError) {
        let status = mdb_txn_commit(handle)
        guard status == MDB_SUCCESS else {
            abort()
            throw CommitError(status)
        }
    }

    package func abort() {
        mdb_txn_abort(handle)
    }

    func database(_ db: Database.Descriptor) -> Database? {
        Database(db, tx: handle)
    }
}
