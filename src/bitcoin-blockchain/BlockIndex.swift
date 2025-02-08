import LMDB
import SystemPackage

/// Block index service.
actor BlockIndex {

    enum AddError: Error {
        case parentMissing
    }

    init(path: FilePath? = .none) {
        if let path {
            db = try! Database(environment: .init(path: path.appending("block-index"), flags: [.noSubDir], maxDBs: 2), name: "by-id", flags: [.create])
            byHeightDB = try! Database(environment: db.environment, name: "by-height", flags: [.create])
            height = byHeightDB.count - 1
        } else {
            db = .none
            byHeightDB = .none
            height = -1
        }
    }

    private let db: Database!
    private let byHeightDB: Database!

    private var byID = [BlockID : BlockRef]()
    private var byHeight = [BlockID]()

    internal private(set) var height: Int

    /// Locators in reverse height order
    var locators: [BlockStorage.Locator] {
        var locators = [BlockStorage.Locator]()
        for id in byHeight.reversed() {
            if let locator = byID[id]!.locator {
                locators.append(locator)
            }
        }
        return locators
    }

    var lastHeaderID: BlockID {
        precondition(height > -1)
        if db == nil {
            return byHeight.last!
        } else {
            return try! byHeightDB.last!
            // If we didn't have byHeightDB…
            // let data = try? db.last
            // return try! BlockRef(binaryData: data!).blockID
        }
    }

    @discardableResult
    func add(_ block: TxBlock, locator: BlockStorage.Locator? = .none, status: BlockRef.ValidationStatus = .header) throws(AddError) -> BlockRef {
        let previous = if block.previous != TxBlock.nullParent && has(block.previous) {
            get(block.previous)
        } else {
            BlockRef?.none
        }
        guard byID.isEmpty || previous != .none else {
            throw AddError.parentMissing
        }
        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        let blockRef = BlockRef(block, height: height, chainwork: chainwork, status: status, locator: locator)
        add(blockRef)
        return blockRef
    }

    func add(_ blockRef: BlockRef) {
        if db == nil {
            byID[blockRef.blockID] = blockRef
            byHeight.append(blockRef.blockID)
        } else {
            try? db.put(blockRef.binaryData, forKey: blockRef.blockID)
            try? byHeightDB.put(blockRef.height.binaryData, forKey: blockRef.blockID)
        }
        height += 1
    }

    func update(_ id: BlockID, locator: BlockStorage.Locator, status: BlockRef.ValidationStatus) {
        if db == nil {
            byID[id]!.locator = locator
            byID[id]!.status = status
        } else if let data = try! db.get(id) {
            var blockRef = try! BlockRef(binaryData: data)
            blockRef.locator = locator
            blockRef.status = status
            try? db.put(blockRef.binaryData, forKey: blockRef.blockID)
            try? byHeightDB.put(blockRef.height.binaryData, forKey: blockRef.blockID)
        }
    }

    func has(_ id: BlockID) -> Bool {
        if db == nil {
            byID[id] != .none
        } else {
            try! db.get(id) != .none
        }
    }

    func get(_ id: BlockID) -> BlockRef { // TODO: Probably throws and return value nil-able
        if db == nil {
            return byID[id]!
        } else {
            let data = try! db.get(id)
            return try! BlockRef(binaryData: data!)
        }
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return .none }
        if db == nil {
            return get(byHeight[height])
        } else {
            let blockID = try! byHeightDB.get(height.binaryData)!
            let blockRefData = try! db.get(blockID)
            return try! BlockRef(binaryData: blockRefData!)
        }
    }

    func get(from startHeight: Int, to endHeight: Int) -> [BlockRef] {
        .init(byHeight[startHeight ... endHeight].map { get($0) })
    }

    func getParent(for childID: BlockID) -> BlockRef? {
        let child = get(childID)
        if child.previous == TxBlock.nullParent {
            return .none
        }
        return get(child.previous)
    }

    func removeAll(from height: Int) -> [BlockRef] {
        var refs = [BlockRef]()
        for h in height ..< byHeight.count {
            refs.append(get(byHeight[h]))
        }
        for ref in refs {
            byID[ref.blockID] = .none
        }
        let totalRemoved = byHeight.count - height
        byHeight.removeLast(totalRemoved)
        self.height -= totalRemoved
        return refs
    }

    func calculateMissingBlocks(_ ids: [BlockID]) -> [BlockID] {
        var missing = [BlockID]()
        for id in ids {
            if byID[id] == .none {
                missing.append(id)
            }
        }
        return missing
    }
}
