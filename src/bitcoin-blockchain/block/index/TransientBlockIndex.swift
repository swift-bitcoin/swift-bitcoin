import Collections
/// In-memory block index service implementation.
actor TransientBlockIndex: BlockIndex {

    private var byID = [Block.ID : BlockRef]()

    /// Either the ID of the Block at each height in the active chain. Or additionally, the IDs of blocks at that height not on the active chain.
    ///
    /// We don't use a simple array to mimic the persistent version of this index which uses a key-value database. This also prepare us for pruning as a future feature.
    private var byHeight = OrderedDictionary<Int, [Block.ID]>()

    var bestHeader: BlockRef? {
        var header: BlockRef? = nil
        for ids in byHeight.values.reversed().prefix(144) {
            for id in ids {
                let ref = byID[id]!
                guard ref.status != .invalid else {
                    continue
                }
                if header == nil || header!.chainwork < ref.chainwork {
                    header = ref
                }
            }
        }
        return header
    }

    var bestBlock: BlockRef {
        for ids in byHeight.values.reversed() {
            for id in ids {
                let ref = byID[id]!
                if ref.status == .active {
                    return ref
                }
            }
        }
        fatalError("Missing genesis block")
    }

    var bestHeader2: BlockRef? {
        for ids in byHeight.values.reversed() {
            if let ref = findActiveRef(ids) {
                return ref
            }
        }
        return nil
    }

    func ancestor(of tip: BlockRef, at height: Int) async -> BlockRef {
        precondition(height <= tip.height)
        var candidate = tip
        while candidate.height > height {
            candidate = byID[candidate.header.previous]!
        }
        return candidate
    }

    func ancestor(of tip: BlockRef, childOf parent: BlockRef) async -> BlockRef? {
        var candidate = tip
        while candidate.height > parent.height, candidate.header.previous != parent.header.id {
            candidate = byID[candidate.header.previous]!
        }
        return if candidate.header.previous == parent.header.id {
            candidate
        } else {
            nil
        }
    }

    func bestAncestor(of header: BlockRef) async -> BlockRef {
        var candidate = header
        while candidate.status != .active {
            candidate = byID[candidate.header.previous]!
        }
        return candidate
    }

    func missingBlocks(tip: BlockRef, stop: BlockRef, max: Int) -> [Block.ID] {
        var current = tip
        var blocks = Deque<Block.ID>(minimumCapacity: max)
        // TODO: It occurred in the past that the stop was not an ancestor of the tip for some reason that neeeds to be looked into
        while current.height > stop.height /* current.header.id != stop.header.id */ {
            if current.status == .header {
                if blocks.count == max {
                    _ = blocks.popLast()
                }
                blocks.prepend(current.header.id)
            }
            current = byID[current.header.previous]!
        }
        return .init(blocks)
    }

    /// All block storage locators in reverse height order, including those for stale/invalid blocks.
    var blockStorageLocators: [BlockStorageLocator] {
        var locators = [BlockStorageLocator]()
        for ids in byHeight.values.reversed() {
            for id in ids {
                if let locator = byID[id]!.locator {
                    locators.append(locator)
                }
            }
        }
        return locators
    }

    func addHeader(_ header: Block) throws(BlockIndexError) -> BlockRef {
        precondition(header.txs.isEmpty)
        return try add(header, locator: nil, status: .header, chainTxCount: -1)
    }

    func addGenesisBlock(_ genesisBlock: Block, locator: BlockStorageLocator) throws(BlockIndexError) -> BlockRef {
        precondition(byID.isEmpty)
        precondition(genesisBlock.previous == Block.nullParent)
        return try add(genesisBlock, locator: locator, status: .active, chainTxCount: genesisBlock.txs.count)
    }

    private func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus, chainTxCount: Int) throws(BlockIndexError) -> BlockRef {
        let previous = if block.previous != Block.nullParent {
            get(block.previous)
        } else {
            BlockRef?.none
        }
        guard byID.isEmpty || previous != nil else {
            throw BlockIndexError.parentMissing
        }
        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        let blockRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)
        byID[blockRef.header.id] = blockRef

        // We might have some previous forks at this height
        if byHeight[height] != nil {
            byHeight[height]!.append(blockRef.header.id)
        } else {
            byHeight[height] = [blockRef.header.id]
        }
        return blockRef
    }

    func updateBlock(_ id: Block.ID, locator: BlockStorageLocator, status: ValidationStatus, chainTxCount: Int) -> BlockRef {
        precondition([.active, .stale].contains(status))
        precondition(locator.isComplete)
        return update(id: id, locator: locator, status: status, chainTxCount: chainTxCount)
    }

    func updateHeader(_ id: Block.ID, locator: BlockStorageLocator) -> BlockRef  {
        precondition(!locator.isPlaceholder && !locator.hasUndoOffset)
        return update(id: id, locator: locator, status: .merkle, chainTxCount: nil)
    }

    private func update(id: Block.ID, locator: BlockStorageLocator, status: ValidationStatus, chainTxCount: Int?) -> BlockRef {
        guard var blockRef = byID[id] else {
            preconditionFailure()
        }

        // Valid transitions header -> merkle; merkle -> active/stale
        precondition(blockRef.status == .header && status == .merkle || (blockRef.status == .merkle && [.active, .stale].contains(status)))

        blockRef.locator = locator
        blockRef.status = status
        if let chainTxCount { blockRef.chainTxCount = chainTxCount }
        byID[id] = blockRef
        return blockRef
    }

    func get(_ id: Block.ID) -> BlockRef? { // TODO: Probably should throw
        byID[id]
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return nil }
        findActiveRef(height)!
    }

    func get(from ref: BlockRef, count: Int) -> [BlockRef] {
        var refs = [BlockRef]()
        var i = 0
        var ref = ref
        repeat {
            refs.append(ref)
            guard ref.header.previous != Block.nullParent else {
                break
            }
            i += 1
            ref = byID[ref.header.previous]!
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
            if byID[id] == nil { missing.append(id) }
        }
        return missing
    }

    func undo(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
        var id = tip.header.id
        var refs = [BlockRef]()
        repeat {
            let ref = byID[id]!
            precondition(ref.status == .active)
            byID[id]!.status = .stale
            refs.append(byID[id]!)
            id = ref.header.previous
        } while id != ancestor.header.id
        return refs
    }

    func reactivate(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
        var id = tip.header.id
        var refs = [BlockRef]()
        repeat {
            let ref = byID[id]!
            id = ref.header.previous
            if ref.status != .stale {
                continue
            }
            byID[ref.header.id]!.status = .active
            refs.insert(byID[ref.header.id]!, at: 0)
        } while id != ancestor.header.id
        return refs
    }

    func makeBlockLocator(from tip: BlockRef) -> [Block.ID] {
        var have = [Block.ID]()
        var step = 1
        var count = step
        var current = tip
        while current.header.previous != Block.nullParent {
            count -= 1
            if count == 0 {
                have.append(current.header.id)
                if have.count >= 10 { step *= 2 }
                count = step
            }
            current = byID[current.header.previous]!
        }
        have.append(current.header.id)
        return have
    }

    func undoLastBlock() -> BlockRef {
        let ref = bestHeader!
        precondition(ref.status == .active) // The chain is fully sync'ed
        byID[ref.header.id]!.status = .stale
        return byID[ref.header.previous]!
    }

    private func findActiveRef(_ height: Int) -> BlockRef? {
        findActiveRef(byHeight[height]!)
    }

    private func findActiveRef(_ ids: [Block.ID]) -> BlockRef? {
        for id in ids {
            guard let ref = byID[id] else {
                fatalError("Missing block ref")
            }
            if ref.status != .invalid || ref.status != .stale {
                return ref
            }
        }
        return nil
    }
}
