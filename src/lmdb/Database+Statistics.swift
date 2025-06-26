import CLMDB

extension Database {

    /// Provides database statistics
    package struct Statistics {

        package let pageSize: UInt32
        package let depth: UInt32
        package let branchPageCount: Int
        package let leafPageCount: Int
        package let overflowPageCount: Int
        package let entries: Int

        init(stat: MDB_stat) {
            self.pageSize = stat.ms_psize
            self.depth = stat.ms_depth
            self.branchPageCount = stat.ms_branch_pages
            self.leafPageCount = stat.ms_leaf_pages
            self.overflowPageCount = stat.ms_overflow_pages
            self.entries = stat.ms_entries
        }
    }
}
