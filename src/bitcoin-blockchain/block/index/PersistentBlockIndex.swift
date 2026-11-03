import LMDB
import BinaryParsing
import _NIOFileSystem
import Foundation
import Logging
import Collections
import BitcoinCrypto
import BitcoinBase

/// Hybrid in-memory / database block index service implementation.
actor PersistentBlockIndex: BlockIndex {

    enum InitError: Error {
        case missingBlockHash
    }

    init(path: FilePath, logger: Logger) throws/*(InitError)*/ {
        self.path = path.appending("block-index")
        self.logger = logger

        // Perform all throwing calls into locals before assigning stored properties:
        // a ~Copyable struct cannot be left partially initialized on a throwing path.
        let env = try initBlockIndexEnv(path: self.path)

        let byID = try env.openDatabase(named: "by-id")
        let byHeight = try env.openDatabase(named: "by-height", options: [.duplicateSort, .duplicateFixed])

        var cache = [BlockHash : BlockRef]()
        var heightsCache = [[BlockHash]]()

        let txn = try ReadTransaction(env)
        let cursor = try Cursor(txn, database: byHeight)
        var maybeHash = try cursor.first()?.value(as: BlockHash.self)
        while let hash = maybeHash {
            guard var ref = try txn.value(forKey: hash, in: byID, as: BlockRef.self) else {
                throw InitError.missingBlockHash
            }
            ref.skip = _ancestor(of: ref, at: skipHeight(from: ref.height), refs: cache).header.id
            if ref.height < heightsCache.count {
                heightsCache[ref.height].append(hash)
            } else if ref.height == heightsCache.count {
                heightsCache.append([hash])
            } else {
                fatalError("Height higher than cache size")
            }
            cache[hash] = ref
            // Move backwards
            if let nextHash = try cursor.nextDuplicate()?.value(as: BlockHash.self) /*try! cursor.get(.nextDup)*/ {
                // If no more duplicates for this height, move to previous height
                maybeHash = nextHash
            } else {
                maybeHash = try cursor.next()?.value(as: BlockHash.self) /*try! cursor.get(.nextNodup)*/
            }
        }
        self.env = env
        self.byID = byID
        self.byHeight = byHeight
        self.cache = cache
        self.heightsCache = heightsCache
    }

    let path: FilePath
    private let logger: Logger
    private let env: Environment
    private let byID: Database
    private let byHeight: Database

    // By id cache
    private var cache = [BlockHash : BlockRef]()

    /// Either the ID of the Block at each height in the active chain. Or additionally, the IDs of blocks at that height not on the active chain.
    private var heightsCache = [[BlockHash]]()

    var bestHeader: BlockRef? {
        var header: BlockRef? = nil
        for ids in heightsCache.reversed().prefix(144) {
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
        for ids in heightsCache.reversed() {
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
        for ids in heightsCache.reversed() {
            if let ref = findActiveRef(ids) {
                return ref
            }
        }
        return nil
    }

    func ancestor(of tip: BlockRef, at height: Int) -> BlockRef {
        _ancestor(of: tip, at: height, refs: cache)
    }

    func bestAncestor(of header: BlockRef) -> BlockRef {
        var candidate = header
        while candidate.status != .active {
            candidate = cache[candidate.header.previous]!
        }
        return candidate
    }

    func lastCommonAncestor(_ blockA: BlockRef, _ blockB: BlockRef) -> BlockRef {
        _lastCommonAncestor(blockA, blockB, refs: cache)
    }

    func missingBlocks(tip: BlockRef, stop: BlockRef, max: Int, exclude: Set<BlockHash>) -> [BlockHash] {
        precondition(max >= 0)

        // TODO: Test this out:
        // let max = min(max, tip.height - stop.height)

        var current = tip
        var blocks = Deque<BlockHash>(minimumCapacity: max)
        // TODO: It has occurred in the past that the stop was not an ancestor of the tip for some reason that neeeds to be looked into
        while current.height > stop.height /* current.header.id != stop.header.id */ {
            if current.status == .header, !exclude.contains(current.header.id) {
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
        for ids in heightsCache.reversed() {
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
        return try add(header, locator: nil, status: .header, chainTxCount: 0)
    }

    func addGenesisBlock(_ genesisBlock: Block, locator: BlockStorageLocator) throws(BlockIndexError) -> BlockRef {
        precondition(cache.isEmpty)
        precondition(genesisBlock.previous == BlockHash.zero)
        return try add(genesisBlock, locator: locator, status: .active, chainTxCount: genesisBlock.txs.count)
    }

    private func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus, chainTxCount: Int) throws(BlockIndexError) -> BlockRef {

        // We can only add a block with locator if it is the genesis block and we have no other blocks
        precondition(locator == nil || cache.isEmpty)

        let previous = if block.previous != BlockHash.zero {
            get(block.previous)
        } else {
            BlockRef?.none
        }

        guard cache.isEmpty || previous != nil else {
            throw BlockIndexError.parentMissing
        }

        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        var newRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)
        newRef.skip = ancestor(of: newRef, at: skipHeight(from: height)).header.id
        cache[newRef.header.id] = newRef

        // We might have some previous forks at this height
        if height < heightsCache.count {
            heightsCache[height].append(newRef.header.id)
        } else if height == heightsCache.count {
            heightsCache.append([newRef.header.id])
        } else {
            fatalError("Height higher than cache size")
        }
        addPersistent(newRef)
        return newRef
    }

    private func addPersistent(_ newRef: BlockRef) {
        // var txn = try! WriteTransaction(env)
        try! env.write { txn in
            try txn.put(newRef, forKey: newRef.header.id, in: byID)
            try txn.put(newRef.header.id, forKey: newRef.height, in: byHeight)
            //try txn.commit()
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
        // var txn = try! WriteTransaction(env)
        try! env.write { txn in
            try txn.put(newRef, forKey: newRef.header.id, in: byID)
            // try! txn.commit()
        }
    }

    func get(_ id: BlockHash) -> BlockRef? { // TODO: Probably should throw
        cache[id]
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeightCache.endIndex else { return nil }
        findActiveRef(height)!
    }

    func getAll(at height: Int) -> [BlockRef] {
        heightsCache[height].map { id in cache[id]! }
    }

    func get(from ref: BlockRef, count: Int) -> [BlockRef] {
        var refs = [BlockRef]()
        var i = 0
        var ref = ref
        repeat {
            refs.append(ref)
            guard ref.header.previous != BlockHash.zero else {
                break
            }
            i += 1
            ref = cache[ref.header.previous]!
        } while i < count
        return refs
    }

    func calculateMissingBlocks(_ ids: [BlockHash]) -> [BlockHash] {
        var missing = [BlockHash]()
        for id in ids {
            guard let ref = cache[id] else {
                missing.append(id)
                continue
            }
            if ref.status == .header {
                missing.append(id)
            }
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
        var id = tip.header.id
        var refs = [BlockRef]()
        // var txn = try! WriteTransaction(env)
        try! env.write { txn in
            repeat {
                var ref = try txn.value(forKey: id, in: byID, as: BlockRef.self)!
                precondition(ref.status == .active)
                ref.status = .stale
                try txn.put(ref, forKey: id, in: byID)
                refs.append(ref)
                id = ref.header.previous
            } while id != ancestor.header.id
            // try! txn.commit()
        }
        return refs
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
        var id = tip.header.id
        var refs = [BlockRef]()
        //var txn = try! WriteTransaction(env)
        try! env.write { txn in
            repeat {
                var ref = try txn.value(forKey: id, in: byID, as: BlockRef.self)!
                id = ref.header.previous
                if ref.status != .stale {
                    continue
                }
                ref.status = .active
                try txn.put(ref, forKey: ref.header.id, in: byID)
                refs.insert(ref, at: 0)
            } while id != ancestor.header.id
            // try! txn.commit()
        }
        return refs
    }

    func makeBlockLocator(from tip: BlockRef) -> [BlockHash] {
        var have = [BlockHash]()
        var step = 1
        var count = step
        var current = tip
        while current.header.previous != BlockHash.zero {
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
        // let readTxn = try! ReadTransaction(env)
        var found = BlockRef?.none
        try! env.read { readTxn in
            let cursor = try! Cursor(readTxn, database: byHeight)

            // Find the best block
            var id = try! cursor.last()!.value(as: BlockHash.self)
            repeat {
                let ref = try! readTxn.value(forKey: id, in: byID, as: BlockRef.self)!
                if ref.status == .active {
                    found = ref
                } else {
                    // Move backwards
                    let maybeID = try! cursor.previousDuplicate()?.value(as: BlockHash.self)
                    // If no more duplicates for this height, move to previous height
                    if let maybeID {
                        id = maybeID
                    } else {
                        id = try! cursor.previous()!.value(as: BlockHash.self)
                    }
                }
            } while found == nil
        }
        var ref = found!

        precondition(ref.status == .active)
        // var txn = try! WriteTransaction(env)
        var previous: BlockRef?
        try! env.write { txn in
            ref.status = .stale
            try! txn.put(ref, forKey: ref.header.id, in: byID)
            // try byID.put(ref.header.id.hash.data, key: ref.data)
            previous = try! txn.value(forKey: ref.header.previous, in: byID, as: BlockRef.self)!
            // try! txn.commit()
        }
        return previous!
    }

    func findChainForks() -> [ChainFork] {
        var forks = [ChainFork]()
        for blockIDs in heightsCache.reversed() {
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

    func clear() async {
        heightsCache = .init()
        cache = .init()
       // await clearPersistent()
    }

    /*
    private func clearPersistent() async {
        env = nil // closes env

        // Removes directory
        let fs = FileSystem.shared
        do {
            try await fs.removeItem(at: path)
        } catch {
            logger.error("Issue removing block index directory: \(error.localizedDescription)")
            return // TODO: Probably throw here
        }

        env = initEnv(path: path)
    }
*/
    private func findActiveRef(_ height: Int) -> BlockRef? {
        findActiveRef(heightsCache[height])
    }

    private func findActiveRef(_ ids: [BlockHash]) -> BlockRef? {
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

/// Turns the lowest `1` bit in the binary representation of a number into a `0`.
private func invertLowestOne(_ n: Int) -> Int { n & (n - 1) }

/// Compute what height to jump back to with the `BlockRef.previous` pointer.
private func skipHeight(from height: Int) -> Int {
    if height < 2 { return 0 }

    // Determine which height to jump back to. Any number strictly lower than height is acceptable, but the following expression seems to perform well in simulations (max 110 steps to go back up to 2**18 blocks).
    return height & 1 != 0 ? invertLowestOne(invertLowestOne(height - 1)) + 1 : invertLowestOne(height)
}

private func _ancestor(of tip: BlockRef, at height: Int, refs: [BlockHash : BlockRef]) -> BlockRef {
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
private func _lastCommonAncestor(_ blockA: BlockRef, _ blockB: BlockRef, refs: [BlockHash : BlockRef]) -> BlockRef {
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

extension BlockHash: LMDBCodable {

    public init(lmdbBytes bytes: RawSpan) throws(LMDBDecodingError) {
        guard let hash = Hash256(bytes: bytes) else {
            throw .init(BlockHash.self, byteCount: bytes.byteCount, reason: "Bad byte count")
        }
        self.init(hash)
    }

    public var encodedByteCount: Int {
        Hash256.byteCount
    }
}

extension BlockRef: LMDBCodable {

    public init(lmdbBytes bytes: RawSpan) throws(LMDBDecodingError) {
        var input = ParserSpan.init(bytes)
        do {
            try self.init(parsing: &input)
        } catch {
            throw .init(BlockRef.self, byteCount: bytes.byteCount, reason: "Malformed")
        }
    }

    public var encodedByteCount: Int {
        self.binarySize
    }

    public func encode(into out: inout OutputRawSpan) {
        try! self.encode(into: &out, format: nil)
    }
}

package func initBlockIndexEnv(path: FilePath) throws -> Environment {
    try Environment(
        path: path.string,
        options: [.noSubdirectory],
        maxDatabases: 2,
        mapSize: 50_000 * Int(getpagesize()) // , fileMode: 0x755 // S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH
    )
}
