/// In-memory block index service implementation.
actor TransientBlockIndex: BlockIndex {

    private var byID = [Block.ID : BlockRef]()
    private var byHeight = [Block.ID]()

    var bestHeader: BlockRef? {
        for id in byHeight.reversed() {
            guard let ref = byID[id] else {
                fatalError("Missing block ref")
            }
            if ref.status != .invalid || ref.status != .stale {
                return ref
            }
        }
        return nil
    }

    func bestAncestor(of header: BlockRef) async -> BlockRef {
        var candidate = header
        while candidate.status != .full {
            candidate = byID[candidate.previous]!
        }
        precondition(![.invalid, .stale].contains(candidate.status))
        return candidate
    }

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

    @discardableResult
    func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus) throws(BlockIndexError) -> BlockRef {
        let previous = if block.previous != Block.nullParent && has(block.previous) {
            get(block.previous)
        } else {
            BlockRef?.none
        }
        guard byID.isEmpty || previous != nil else {
            throw BlockIndexError.parentMissing
        }
        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        let chainTxCount = if let previous { previous.chainTxCount + block.txs.count } else { block.txs.count }
        let blockRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)
        byID[blockRef.header.id] = blockRef
        byHeight.append(blockRef.header.id)
        return blockRef
    }

    func update(_ id: Block.ID, locator: BlockStorageLocator, status: ValidationStatus) -> BlockRef {
        byID[id]!.locator = locator
        byID[id]!.status = status
        return byID[id]!
    }

    @discardableResult
    func update(_ id: Block.ID, status: ValidationStatus) -> BlockRef {
        // TODO: deal with duplication of the different `update()` funcs.
        byID[id]!.status = status
        return byID[id]!
    }

    func has(_ id: Block.ID) -> Bool {
        byID[id] != nil
    }

    func get(_ id: Block.ID) -> BlockRef { // TODO: Probably throws and return value nil-able
        byID[id]!
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return nil }
        get(byHeight[height])
    }

    func get(from ref: BlockRef, count: Int) -> [BlockRef] {
        var refs = [BlockRef]()
        var i = 0
        var ref = ref
        repeat {
            refs.append(ref)
            guard ref.previous != Block.nullParent else {
                break
            }
            i += 1
            ref = byID[ref.previous]!
        } while i < count
        return refs
    }

    /*
    func getParent(for childID: Block.ID) -> BlockRef? {
        let child = get(childID)
        if child.previous == Block.nullParent {
            return nil
        }
        return get(child.previous)
    }
    */

    /*
    /// Either removes (if header-only) or marks block as invalid
    func removeAll(from height: Int) -> BlockRef {
        precondition(height > 0)
        var refs = [BlockRef]()
        for h in height ... byHeight.count - 1 {
            refs.append(get(at: h))
        }
        for ref in refs {
            if ref.status == .header {
                byID[ref.header.id] = nil
            } else {
                update(ref.header.id, status: .invalid)
            }
        }
        let totalRemoved = byHeight.count - height
        byHeight.removeLast(totalRemoved)
        return byID[byHeight[height - 1]]!
    }
    */

    func calculateMissingBlocks(_ ids: [Block.ID]) -> [Block.ID] {
        var missing = [Block.ID]()
        for id in ids {
            if has(id) { missing.append(id) }
        }
        return missing
    }

    func undoLastBlock() -> BlockRef {
        let id = byHeight.last!
        let ref = byID[id]!
        precondition(ref.status == .full) // The chain is fully sync'ed
        byID[id]!.status = .stale
        return byID[ref.previous]!
    }
}
