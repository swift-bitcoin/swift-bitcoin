import LMDB
import SystemPackage

/// Database block index service implementation.
actor DBBlockIndex: BlockIndex {

    init(path: FilePath) {
        db = try! Database(environment: .init(path: path.appending("block-index"), flags: [.noSubDir], maxDBs: 2), name: "by-id", flags: [.create])
        byHeightDB = try! Database(environment: db.environment, name: "by-height", flags: [.create, .integerKey])
        height = byHeightDB.count - 1
    }

    private let db: Database!
    private let byHeightDB: Database!

    /// Active chain height only, includes headers of unverified blocks.
    internal private(set) var height: Int

    /// Locators in reverse height order
    var locators: [BlockStorageLocator] {
        var locators = [BlockStorageLocator]()
        for i in height ... 0 {
            let blockID = try! byHeightDB.get(i)!
            let ref = get(blockID)
            if let locator = ref.locator {
                locators.append(locator)
            }
        }
        return locators
    }

    var lastHeaderID: BlockID {
        precondition(height > -1)
        return try! byHeightDB.last!
        // If we didn't have byHeightDB…
        // let data = try? db.last
        // return try! BlockRef(binaryData: data!).blockID
    }

    @discardableResult
    func add(_ block: TxBlock, locator: BlockStorageLocator?, status: BlockRef.ValidationStatus) throws(BlockIndexError) -> BlockRef {
        let previous = if block.previous != TxBlock.nullParent && has(block.previous) {
            get(block.previous)
        } else {
            BlockRef?.none
        }
        guard db.count == 0 || previous != .none else {
            throw BlockIndexError.parentMissing
        }
        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        let chainTxCount = if let previous { previous.chainTxCount + block.txs.count } else { block.txs.count }
        let blockRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)
        add(blockRef)
        return blockRef
    }

    func add(_ blockRef: BlockRef) {
        try? db.put(blockRef.binaryData, forKey: blockRef.blockID)
        try? byHeightDB.put(blockRef.blockID, key: blockRef.height)
        height += 1
    }

    func update(_ id: BlockID, locator: BlockStorageLocator, status: BlockRef.ValidationStatus) {
        guard let data = try! db.get(id) else { return }
        var blockRef = try! BlockRef(binaryData: data)
        blockRef.locator = locator
        blockRef.status = status
        try? db.put(blockRef.binaryData, forKey: blockRef.blockID)
        try? byHeightDB.put(blockRef.blockID, key: blockRef.height)
    }

    func update(_ id: BlockID, status: BlockRef.ValidationStatus) {
        // TODO: deal with duplication of the different `update()` funcs.
        guard let data = try! db.get(id) else { return }
        var blockRef = try! BlockRef(binaryData: data)
        blockRef.status = status
        try? db.put(blockRef.binaryData, forKey: blockRef.blockID)
        try? byHeightDB.put(blockRef.blockID, key: blockRef.height)
    }

    func has(_ id: BlockID) -> Bool {
        try! db.get(id) != .none
    }

    func get(_ id: BlockID) -> BlockRef { // TODO: Probably throws and return value nil-able
        let data = try! db.get(id)
        return try! BlockRef(binaryData: data!)
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return .none }
        let blockID = try! byHeightDB.get(height)!
        let blockRefData = try! db.get(blockID)
        return try! BlockRef(binaryData: blockRefData!)
    }

    func get(from startHeight: Int, to endHeight: Int) -> [BlockRef] {
        (startHeight...endHeight).map { get(at: $0) }
    }

    func getParent(for childID: BlockID) -> BlockRef? {
        let child = get(childID)
        if child.previous == TxBlock.nullParent {
            return .none
        }
        return get(child.previous)
    }

    /// Either removes (if header-only) or marks block as stale
    func removeAll(from height: Int) -> [BlockRef] {
        var refs = [BlockRef]()
        for h in height ... self.height {
            refs.append(get(at: h))
        }
        for ref in refs {
            if ref.status < .full {
                try! db.deleteValue(forKey: ref.blockID)
            } else {
                update(ref.blockID, status: .stale)
            }
        }
        let totalRemoved = byHeightDB.count - height
        for h in height ... self.height {
            try! byHeightDB.deleteValue(h)
        }
        self.height -= totalRemoved
        return refs
    }

    func calculateMissingBlocks(_ ids: [BlockID]) -> [BlockID] {
        var missing = [BlockID]()
        for id in ids {
            if has(id) {
                missing.append(id)
            }
        }
        return missing
    }
}
