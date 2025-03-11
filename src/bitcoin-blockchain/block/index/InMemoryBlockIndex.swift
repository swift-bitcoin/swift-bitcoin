/// In-memory block index service implementation.
actor InMemoryBlockIndex: BlockIndex {

    init() {
        height = -1
    }

    private var byID = [BlockID : BlockRef]()
    private var byHeight = [BlockID]()

    /// Active chain height only, includes headers of unverified blocks.
    internal private(set) var height: Int

    /// Locators in reverse height order
    var locators: [BlockStorageLocator] {
        var locators = [BlockStorageLocator]()
        for id in byHeight.reversed() {
            if let locator = byID[id]!.locator {
                locators.append(locator)
            }
        }
        return locators
    }

    var lastHeaderID: BlockID {
        precondition(height > -1)
        return byHeight.last!
    }

    @discardableResult
    func add(_ block: TxBlock, locator: BlockStorageLocator?, status: BlockRef.ValidationStatus) throws(BlockIndexError) -> BlockRef {
        let previous = if block.previous != TxBlock.nullParent && has(block.previous) {
            get(block.previous)
        } else {
            BlockRef?.none
        }
        guard byID.isEmpty || previous != .none else {
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
        byID[blockRef.blockID] = blockRef
        byHeight.append(blockRef.blockID)
        height += 1
    }

    func update(_ id: BlockID, locator: BlockStorageLocator, status: BlockRef.ValidationStatus) {
        byID[id]!.locator = locator
        byID[id]!.status = status
    }

    func update(_ id: BlockID, status: BlockRef.ValidationStatus) {
        // TODO: deal with duplication of the different `update()` funcs.
        byID[id]!.status = status
    }

    func has(_ id: BlockID) -> Bool {
        byID[id] != .none
    }

    func get(_ id: BlockID) -> BlockRef { // TODO: Probably throws and return value nil-able
        byID[id]!
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return .none }
        get(byHeight[height])
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
                byID[ref.blockID] = .none

            } else {
                update(ref.blockID, status: .stale)
            }
        }
        let totalRemoved = byHeight.count - height
        byHeight.removeLast(totalRemoved)
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
