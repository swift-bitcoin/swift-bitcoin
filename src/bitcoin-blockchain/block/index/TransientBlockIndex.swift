import Collections

/// In-memory block index service implementation.
struct TransientBlockIndex: BlockIndex {

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


    /// Finds the ancestor of block at a given height.
    ///
    /// Naive implementation with no skip list
    func ancestorNaive(of tip: BlockRef, at height: Int) -> BlockRef {
        precondition(height <= tip.height)
        var candidate = tip
        while candidate.height > height {
            candidate = byID[candidate.header.previous]!
        }
        return candidate
    }

    /// Finds the ancestor of block at a given height.
    ///
    /// Uses skip list for performance.
    func ancestor(of tip: BlockRef, at height: Int) -> BlockRef {
        _ancestor(of: tip, at: height, refs: byID)
    }


    func bestAncestor(of header: BlockRef) -> BlockRef {
        var candidate = header
        while candidate.status != .active {
            candidate = byID[candidate.header.previous]!
        }
        return candidate
    }

    func lastCommonAncestor(_ blockA: BlockRef, _ blockB: BlockRef) -> BlockRef {
        _lastCommonAncestor(blockA, blockB, refs: byID)
    }

    func missingBlocks(tip: BlockRef, stop: BlockRef, max: Int, exclude: Set<Block.ID>) -> [Block.ID] {
        precondition(max >= 0)

        // TODO: Test this out:
        // let max = min(max, tip.height - stop.height)

        var current = tip
        var blocks = Deque<Block.ID>(minimumCapacity: max)
        // TODO: It occurred in the past that the stop was not an ancestor of the tip for some reason that neeeds to be looked into
        while current.height > stop.height /* current.header.id != stop.header.id */ {
            if current.status == .header, !exclude.contains(current.header.id) {
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
    var storageLocators: [BlockStorageLocator] {
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

    mutating func addHeader(_ header: Block) throws(BlockIndexError) -> BlockRef {
        precondition(header.txs.isEmpty)
        return try add(header, locator: nil, status: .header, chainTxCount: -1)
    }

    mutating func addGenesisBlock(_ genesisBlock: Block, locator: BlockStorageLocator) throws(BlockIndexError) -> BlockRef {
        precondition(byID.isEmpty)
        precondition(genesisBlock.previous == Block.nullParent)
        return try add(genesisBlock, locator: locator, status: .active, chainTxCount: genesisBlock.txs.count)
    }

    private mutating func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus, chainTxCount: Int) throws(BlockIndexError) -> BlockRef {
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
        var newRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)
        newRef.skip = ancestor(of: newRef, at: skipHeight(from: height)).header.id
        byID[newRef.header.id] = newRef

        // We might have some previous forks at this height
        if byHeight[height] != nil {
            byHeight[height]!.append(newRef.header.id)
        } else {
            byHeight[height] = [newRef.header.id]
        }
        return newRef
    }

    mutating func updateBlock(_ ref: BlockRef, locator: BlockStorageLocator, status: ValidationStatus, chainTxCount: Int) -> BlockRef {
        precondition([.active, .stale].contains(status))
        precondition(locator.isComplete)
        return update(ref, locator: locator, status: status, chainTxCount: chainTxCount)
    }

    mutating func updateHeader(_ ref: BlockRef, locator: BlockStorageLocator) -> BlockRef  {
        precondition(!locator.isPlaceholder && !locator.hasUndoOffset)
        return update(ref, locator: locator, status: .merkle, chainTxCount: nil)
    }

    private mutating func update(_ ref: BlockRef, locator: BlockStorageLocator, status: ValidationStatus, chainTxCount: Int?) -> BlockRef {
        var blockRef = ref

        // Valid transitions header -> merkle; merkle -> active/stale
        precondition(blockRef.status == .header && status == .merkle || (blockRef.status == .merkle && [.active, .stale].contains(status)))

        blockRef.locator = locator
        blockRef.status = status
        if let chainTxCount { blockRef.chainTxCount = chainTxCount }
        byID[ref.header.id] = blockRef
        return blockRef
    }

    func get(_ id: Block.ID) -> BlockRef? { // TODO: Probably should throw
        byID[id]
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return nil }
        findActiveRef(height)!
    }

    func getAll(at height: Int) -> [BlockRef] {
        byHeight[height]!.map { id in byID[id]! }
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

    mutating func undo(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
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

    mutating func reactivate(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
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

    mutating func undoLastBlock() -> BlockRef {
        let ref = bestHeader!
        precondition(ref.status == .active) // The chain is fully sync'ed
        byID[ref.header.id]!.status = .stale
        return byID[ref.header.previous]!
    }

    func findChainForks() -> [ChainFork] {
        var forks = [ChainFork]()
        for blockIDs in byHeight.values.reversed() {
            for blockID in blockIDs {
                let ref = byID[blockID]!
                var foundBestChild = false
                for (i, fork) in forks.enumerated() {
                    if fork.start.header.previous == blockID {
                        forks[i].start = ref
                        foundBestChild = true
                        break
                    }
                }
                if !foundBestChild {
                    forks.append(.init(ref))
                    forks.sort { $0 > $1 }
                }
            }
        }
        return forks
    }

    mutating func clear() {
        byHeight = .init()
        byID = .init()
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

/// Turns the lowest `1` bit in the binary representation of a number into a `0`.
private func invertLowestOne(_ n: Int) -> Int { n & (n - 1) }

/// Compute what height to jump back to with the `BlockRef.previous` pointer.
private func skipHeight(from height: Int) -> Int {
    if height < 2 { return 0 }

    // Determine which height to jump back to. Any number strictly lower than height is acceptable, but the following expression seems to perform well in simulations (max 110 steps to go back up to 2**18 blocks).
    return height & 1 != 0 ? invertLowestOne(invertLowestOne(height - 1)) + 1 : invertLowestOne(height)
}

private func _ancestor(of tip: BlockRef, at height: Int, refs: [Block.ID : BlockRef]) -> BlockRef {
    precondition(height <= tip.height)
    var indexWalk = tip // const CBlockIndex* pindexWalk = this;
    var heightWalk = tip.height
    while (heightWalk > height) {
        let heightSkip = skipHeight(from: heightWalk)
        let heightSkipPrev = skipHeight(from: heightWalk - 1)
        if let skip = indexWalk.skip, heightSkip == height || (
            heightSkip > height && !(
                heightSkipPrev < heightSkip - 2 && heightSkipPrev >= height))
        {
            // Only follow skip if previous->skip isn't better than skip->previous.
            indexWalk = refs[skip]!
            heightWalk = heightSkip
        } else {
            indexWalk = refs[indexWalk.header.previous]!
            heightWalk -= 1
        }
    }
    return indexWalk
}

/// Find the last common ancestor two blocks have.
private func _lastCommonAncestor(_ blockA: BlockRef, _ blockB: BlockRef, refs: [Block.ID : BlockRef]) -> BlockRef {
    var pa: BlockRef
    var pb: BlockRef
    // First rewind to the last common height (the forking point cannot be past one of the two).
    if blockA.height > blockB.height {
        pb = blockB
        pa = _ancestor(of: blockA, at: blockB.height, refs: refs)
    } else if blockB.height > blockA.height {
        pa = blockA
        pb = _ancestor(of: blockB, at: blockA.height, refs: refs)
    } else {
        pa = blockA
        pb = blockB
    }
    while pa.header.id != pb.header.id {
        // Jump back until pa and pb have a common "skip" ancestor.
        assert(pa.skip != nil && pb.skip != nil)
        while pa.skip != pb.skip { // TODO: check what happens when skip is null for one of them
            // This logic relies on the property that equal-height blocks have equal-height skip
            // pointers.
            assert(pa.height == pb.height)
            //assert(pa->pskip->nHeight == pb->pskip->nHeight); // check moved down 2 lines
            pa = refs[pa.skip!]!
            pb = refs[pb.skip!]!
            assert(pa.height == pb.height)
            assert(pa.skip != nil && pb.skip != nil)
        }
        // At this point, pa and pb are different, but have equal pskip. The forking point lies in
        // between pa/pb on the one end, and pa->pskip/pb->pskip on the other end.
        pa = refs[pa.header.previous]!
        pb = refs[pb.header.previous]!
    }
    return pa
}
