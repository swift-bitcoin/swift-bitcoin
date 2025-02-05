/// Block index service.
actor BlockIndex {

    enum AddError: Error {
        case parentMissing
    }

    private var byID = [BlockID : BlockRef]()
    private var byHeight = [BlockID]()

    var height: Int {
        byHeight.count - 1
    }

    /// Locators in reverse height order
    var locators: [BlockStorage.Locator] {
        var locators = [BlockStorage.Locator]()
        for id in byHeight.reversed() {
            locators.append(byID[id]!.locator)
        }
        return locators
    }

    var lastHeaderID: BlockID {
        precondition(byHeight.count > 0)
        return byHeight.last!
    }

    @discardableResult
    func add(_ block: TxBlock, locator: BlockStorage.Locator, status: BlockRef.ValidationStatus = .header) throws(AddError) -> BlockRef {
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
        let blockRef = BlockRef(block, height: height, locator: locator, chainwork: chainwork, status: status)
        add(blockRef)
        return blockRef
    }

    func add(_ blockRef: BlockRef) {
        byID[blockRef.blockID] = blockRef
        byHeight.append(blockRef.blockID)
    }

    func update(_ id: BlockID, with status: BlockRef.ValidationStatus) {
        byID[id]!.status = status
    }

    func has(_ id: BlockID) -> Bool {
        byID[id] != .none
    }

    func get(_ id: BlockID) -> BlockRef {
        byID[id]!
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return .none }
        return get(byHeight[height])
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
        byHeight.removeLast(byHeight.count - height)
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
