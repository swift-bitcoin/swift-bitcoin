import LMDB
import _NIOFileSystem
import struct SystemPackage.FilePath
import Foundation
import Logging
import Collections

/// Hybrid in-memory / database block index service implementation.
actor HybridBlockIndex: BlockIndex {

    init(path: FilePath, logger: Logger) {
        self.path = path.appending("block-index")
        self.logger = logger
        env = initEnv(path: self.path)

        var cache = [Block.ID : BlockRef]()
        var cache2 = [[Block.ID]]()

        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            try! byHeight.withCursor(readOnly: true) { cursor in
                var maybeID = try! cursor.get(.first)
                while let id = maybeID {
                    let ref = try! _get(id, byID: byID)!
                    if cache2.count <= ref.height {
                        cache2.append([id])
                    } else {
                        cache2[ref.height].append(id)
                    }
                    cache[id] = ref
                    // Move backwards
                    if let nextID = try! cursor.get(.nextDup) {
                        // If no more duplicates for this height, move to previous height
                        maybeID = nextID
                    } else {
                        maybeID = try! cursor.get(.nextNodup)
                    }
                }
            }
        }
        self.cache = cache
        self.cache2 = cache2
    }

    private let path: FilePath
    private let logger: Logger
    private var env: Environment!

    // By id cache
    private var cache = [Block.ID : BlockRef]()

    /// Either the ID of the Block at each height in the active chain. Or additionally, the IDs of blocks at that height not on the active chain.
    private var cache2 = [[Block.ID]]()

    var bestHeader: BlockRef? {
        var header: BlockRef? = nil
        for ids in cache2.reversed().prefix(144) {
            for id in ids {
                let ref = cache[id]!
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
        for ids in cache2.reversed() {
            for id in ids {
                let ref = cache[id]!
                if ref.status == .active {
                    return ref
                }
            }
        }
        fatalError("Missing genesis block")
    }

    var bestHeader2: BlockRef? {
        for ids in cache2.reversed() {
            if let ref = findActiveRef(ids) {
                return ref
            }
        }
        return nil
    }

    func ancestor(of tip: BlockRef, at height: Int) -> BlockRef {
        precondition(height <= tip.height)
        var candidate = tip
        while candidate.height > height {
            candidate = cache[candidate.header.previous]!
        }
        return candidate
    }

    func bestAncestor(of header: BlockRef) -> BlockRef {
        var candidate = header
        while candidate.status != .active {
            candidate = cache[candidate.header.previous]!
        }
        return candidate
    }

    func missingBlocks(tip: BlockRef, stop: BlockRef, max: Int) -> [Block.ID] {
        precondition(max >= 0)

        // TODO: Test this out:
        // let max = min(max, tip.height - stop.height)

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
            current = cache[current.header.previous]!
        }
        return .init(blocks)
    }

    /// All block storage locators in reverse height order, including those for stale/invalid blocks.
    var storageLocators: [BlockStorageLocator] {
        var locators = [BlockStorageLocator]()
        for ids in cache2.reversed() {
            for id in ids {
                if let locator = cache[id]!.locator {
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
        precondition(cache.isEmpty)
        precondition(genesisBlock.previous == Block.nullParent)
        return try add(genesisBlock, locator: locator, status: .active, chainTxCount: genesisBlock.txs.count)
    }

    private func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus, chainTxCount: Int) throws(BlockIndexError) -> BlockRef {

        // We can only add a block with locator if it is the genesis block and we have no other blocks
        precondition(locator == nil || cache.isEmpty)

        let previous = if block.previous != Block.nullParent {
            get(block.previous)
        } else {
            BlockRef?.none
        }

        guard cache.isEmpty || previous != nil else {
            throw BlockIndexError.parentMissing
        }

        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        let newRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)
        cache[newRef.header.id] = newRef

        // We might have some previous forks at this height
        if cache2.count <= height {
            cache2[height].append(newRef.header.id)
        } else {
            cache2[height] = [newRef.header.id]
        }
        addPersistent(newRef)
        return newRef
    }

    private func addPersistent(_ newRef: BlockRef) {
        // Add
        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(newRef.data, key: newRef.header.id)
            try byHeight.put(newRef.header.id, key: newRef.height)
        }
    }

    func updateBlock(_ ref: BlockRef, locator: BlockStorageLocator, status: ValidationStatus, chainTxCount: Int) -> BlockRef {
        precondition([.active, .stale].contains(status))
        precondition(locator.isComplete)
        return update(ref, locator: locator, status: status, chainTxCount: chainTxCount)
    }

    func updateHeader(_ ref: BlockRef, locator: BlockStorageLocator) -> BlockRef  {
        precondition(!locator.isPlaceholder && !locator.hasUndoOffset)
        return update(ref, locator: locator, status: .merkle, chainTxCount: nil)
    }

    private func update(_ ref: BlockRef, locator: BlockStorageLocator, status: ValidationStatus, chainTxCount: Int?) -> BlockRef {

        // Valid transitions header -> merkle; merkle -> active/stale
        precondition(ref.status == .header && status == .merkle || (ref.status == .merkle && [.active, .stale].contains(status)))

        var newRef = ref
        newRef.locator = locator
        newRef.status = status
        if let chainTxCount { newRef.chainTxCount = chainTxCount }
        cache[ref.header.id] = newRef
        updatePersistent(newRef)
        return newRef
    }

    private func updatePersistent(_ newRef: BlockRef) {
        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(newRef.data, key: newRef.header.id)
        }
    }

    func get(_ id: Block.ID) -> BlockRef? { // TODO: Probably should throw
        cache[id]
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeightCache.endIndex else { return nil }
        findActiveRef(height)!
    }

    func getAll(at height: Int) -> [BlockRef] {
        cache2[height].map { id in cache[id]! }
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
            ref = cache[ref.header.previous]!
        } while i < count
        return refs
    }

    func calculateMissingBlocks(_ ids: [Block.ID]) -> [Block.ID] {
        var missing = [Block.ID]()
        for id in ids {
            if cache[id] == nil { missing.append(id) }
        }
        return missing
    }

    func undo(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
        var id = tip.header.id
        var refs = [BlockRef]()
        repeat {
            let ref = cache[id]!
            precondition(ref.status == .active)
            cache[id]!.status = .stale
            refs.append(cache[id]!)
            id = ref.header.previous
        } while id != ancestor.header.id
        let refs2 = undoPersistent(from: tip, backTo: ancestor)
        assert(refs == refs2) // TODO: Remove for efficiency
        return refs
    }

    private func undoPersistent(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
        try! env.withTransaction(db: byID) { _, byID in
            var id = tip.header.id
            var refs = [BlockRef]()
            repeat {
                var ref = try _get(id, byID: byID)!
                precondition(ref.status == .active)
                ref.status = .stale
                try byID.put(ref.data, key: id)
                refs.append(ref)
                id = ref.header.previous
            } while id != ancestor.header.id
            return refs
        }
    }

    func reactivate(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
        var id = tip.header.id
        var refs = [BlockRef]()
        repeat {
            let ref = cache[id]!
            id = ref.header.previous
            if ref.status != .stale {
                continue
            }
            cache[ref.header.id]!.status = .active
            refs.insert(cache[ref.header.id]!, at: 0)
        } while id != ancestor.header.id
        let refs2 = reactivatePersistent(from: tip, backTo: ancestor)
        assert(refs == refs2) // TODO: Remove for efficiency
        return refs
    }

    private func reactivatePersistent(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
        try! env.withTransaction(db: byID) { _, byID in
            var id = tip.header.id
            var refs = [BlockRef]()
            repeat {
                var ref = try _get(id, byID: byID)!
                id = ref.header.previous
                if ref.status != .stale {
                    continue
                }
                ref.status = .active
                try byID.put(ref.data, key: ref.header.id)
                refs.insert(ref, at: 0)
            } while id != ancestor.header.id
            return refs
        }
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
            current = cache[current.header.previous]!
        }
        have.append(current.header.id)
        return have
    }

    func undoLastBlock() -> BlockRef {
        let ref = bestHeader!
        precondition(ref.status == .active) // The chain is fully sync'ed
        cache[ref.header.id]!.status = .stale
        let result = cache[ref.header.previous]!
        let result2 = undoLastBlockPersistent()
        assert(result == result2) // TODO: Remove for efficiency
        return result
    }

    private func undoLastBlockPersistent() -> BlockRef {
        var ref = try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            findBestBlock(byID: byID, byHeight: byHeight)
        }
        precondition(ref.status == .active)
        return try! env.withTransaction(db: byID) { _, byID in
            ref.status = .stale
            try byID.put(ref.header.id, key: ref.data)
            let previousData = try byID.get(ref.header.previous)!
            return try BlockRef(previousData)
        }
    }

    func findChainForks() -> [ChainFork] {
        var forks = [ChainFork]()
        for blockIDs in cache2.reversed() {
            for blockID in blockIDs {
                let ref = cache[blockID]!
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

    func clear() {
        cache2 = .init()
        cache = .init()
    }

    private func findActiveRef(_ height: Int) -> BlockRef? {
        findActiveRef(cache2[height])
    }

    private func findActiveRef(_ ids: [Block.ID]) -> BlockRef? {
        for id in ids {
            guard let ref = cache[id] else {
                fatalError("Missing block ref")
            }
            if ref.status != .invalid || ref.status != .stale {
                return ref
            }
        }
        return nil
    }
}

private let byIDName = "by-id"
private let byHeightName = "by-height"
private let byID = Database.Descriptor(byIDName)
private let byHeight = Database.Descriptor(byHeightName)


private func _get(_ id: Block.ID, byID: borrowing LMDB.Database) throws(CoinsError) -> BlockRef? {
    let data: Data?
    do {
        data = try byID.get(id)
    } catch {
        throw .databaseError(error)
    }
    guard let data else {
        return nil
    }
    do {
        return try BlockRef(data)
    } catch {
        throw .corruptedCoinData
    }
}

private func findBestBlock(byID: borrowing LMDB.Database, byHeight: borrowing LMDB.Database) -> BlockRef {
    try! byHeight.withCursor(readOnly: true) { cursor in
        var id = try! cursor.get(.last)!
        var found = BlockRef?.none
        repeat {
            let ref = try! _get(id, byID: byID)!
            if ref.status == .active {
                found = ref
            } else {
                // Move backwards
                let maybeID = try! cursor.get(.prevDup)
                // If no more duplicates for this height, move to previous height
                if let maybeID {
                    id = maybeID
                } else {
                    id = try! cursor.get(.prevNodup)!
                }
            }
        } while found == nil
        return found!
    }
}

private func initEnv(path: FilePath) -> Environment {
    let env = try! Environment(at: URL(filePath: path.string), maxDBs: 2, pages: 50_000, options: [.noSubDir])
    try! env.createDB(byID)
    try! env.withTransaction(db: .init(byHeightName, options: [.create, .integerKey, .duplicateSort, .duplicateFixed])) { _, _ in }
    return env
}
