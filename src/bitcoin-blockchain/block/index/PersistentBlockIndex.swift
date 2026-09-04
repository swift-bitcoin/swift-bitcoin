import BitcoinBase
import LMDB
import _NIOFileSystem
import struct SystemPackage.FilePath
import Foundation
import Logging
import Collections

/// Database block index service implementation.
actor PersistentBlockIndex: BlockIndex {

    // TODO: Get rid of the entire PersistentBlockIndex implementation as it was superseeded by the HybridBlockIndex which is persistent but also has an in-memory cache.
    func lastCommonAncestor(_ blockA: BlockRef, _ blockB: BlockRef) async -> BlockRef {
        fatalError("Not implemented")
    }

    init(path: FilePath, logger: Logger) {
        self.path = path.appending("block-index")
        self.logger = logger
        env = initEnv(path: self.path)
    }

    private let path: FilePath
    private let logger: Logger
    private var env: Environment!

    var bestHeader: BlockRef? {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            try! byHeight.withCursor(readOnly: true) { cursor in
                var header: BlockRef? = nil
                var maybeID = try! cursor.get(.last)
                var maxSteps = 144 // Blocks in a period
                while let id = maybeID, maxSteps > 0 {
                    let ref = try! _get(id, byID: byID)!
                    // Move backwards
                    if let nextID = try! cursor.get(.prevDup) {
                        // If no more duplicates for this height, move to previous height
                        maybeID = nextID
                    } else {
                        maybeID = try! cursor.get(.prevNodup)
                        maxSteps -= 1
                    }
                    guard ref.status != .invalid else {
                        continue
                    }
                    if header == nil || header!.chainwork < ref.chainwork {
                        header = ref
                    }
                }
                return header
            }
        }
    }

    var bestBlock: BlockRef {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            try! byHeight.withCursor(readOnly: true) { cursor in
                var id = try! cursor.get(.last)!
                var found = BlockRef?.none
                repeat {
                    let ref = try! _get(id, byID: byID)!
                    if ref.status == .active {
                        found = ref
                    } else if let maybeID = try! cursor.get(.prevDup) { // Move backwards
                        // If no more duplicates for this height, move to previous height
                        id = maybeID
                    } else {
                        id = try! cursor.get(.prevNodup)!
                    }
                } while found == nil
                return found!
            }
        }
    }

    func ancestor(of tip: BlockRef, at height: Int) async -> BlockRef {
        precondition(height <= tip.height)
        return try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            var candidate = tip
            while candidate.height > height {
                candidate = try! _get(candidate.header.previous, byID: byID)!
            }
            return candidate
        }
    }

    func bestAncestor(of header: BlockRef) -> BlockRef {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            var candidate = header
            while candidate.status != .active {
                candidate = try! _get(candidate.header.previous, byID: byID)!
            }
            return candidate
        }
    }

    func missingBlocks(tip: BlockRef, stop: BlockRef, max: Int, exclude: Set<Block.ID>) -> [Block.ID] {
        precondition(max >= 0)

        // TODO: Test this out:
        // let max = min(max, tip.height - stop.height)

        return try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
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
                current = try! _get(current.header.previous, byID: byID)!
            }
            return .init(blocks)
        }
    }

    func addHeader(_ header: Block) throws(BlockIndexError) -> BlockRef {
        precondition(header.txs.isEmpty)
        return try add(header, locator: nil, status: .header, chainTxCount: 0)
    }

    func addGenesisBlock(_ genesisBlock: Block, locator: BlockStorageLocator) throws(BlockIndexError) -> BlockRef {
        precondition(genesisBlock.previous == Block.nullParent)
        return try add(genesisBlock, locator: locator, status: .active, chainTxCount: genesisBlock.txs.count)
    }

    private func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus, chainTxCount: Int) throws(BlockIndexError) -> BlockRef {
        let previous: BlockRef?
        let count: Int
        (previous, count) = try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            let previous: BlockRef?
            if block.previous != Block.nullParent, let previousBlock = try byID.get(block.previous) {
                previous = try! BlockRef(previousBlock)
            } else {
                previous = nil
            }
            return (previous, try byID.count)
        }

        // We can only add the genesis block if the database is empty
        precondition(locator == nil || count == 0)

        guard count == 0 || previous != nil else {
            throw BlockIndexError.parentMissing
        }
        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        let blockRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)

        // Add
        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(blockRef.data, key: blockRef.header.id)
            try byHeight.put(blockRef.header.id, key: blockRef.height)
        }
        return blockRef
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
        var blockRef = ref

        // Valid transitions header -> merkle; merkle -> active/stale
        precondition(blockRef.status == .header && status == .merkle || (blockRef.status == .merkle && [.active, .stale].contains(status)))

        blockRef.locator = locator
        blockRef.status = status
        if let chainTxCount { blockRef.chainTxCount = chainTxCount }

        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(blockRef.data, key: blockRef.header.id)
            // try byHeight.put(blockRef.header.id, key: blockRef.height)
        }
        return blockRef
    }

    func get(_ id: Block.ID) -> BlockRef? { // TODO: Probably should throw
        let data = try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            try byID.get(id)
        }
        return if let data {
            try! BlockRef(data)
        } else {
            nil
        }
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return nil }
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            try byHeight.withCursor(readOnly: true) { cursor in
                try cursor.set(key: height)
                var maybeBlockID = try cursor.get(.firstDup)
                var found: BlockRef? = nil
                while found == nil, let blockID = maybeBlockID {
                    let refData = try byID.get(blockID)!
                    let ref = try BlockRef(refData)
                    if ![.stale, .invalid].contains(ref.status) {
                        found = ref
                    }
                    maybeBlockID = try cursor.get(.nextDup)
                }
                return found!
            }
        }
    }

    func getAll(at height: Int) -> [BlockRef] {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            var all = [BlockRef]()
            try byHeight.withCursor(readOnly: true) { cursor in
                try cursor.set(key: height)
                var maybeBlockID = try cursor.get(.firstDup)
                while let blockID = maybeBlockID {
                    let refData = try byID.get(blockID)!
                    let ref = try BlockRef(refData)
                    all.append(ref)
                    maybeBlockID = try cursor.get(.nextDup)
                }
            }
            return all
        }
    }

    func get(from ref: BlockRef, count: Int) -> [BlockRef] {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in

            var refs = [BlockRef]()
            var i = 0
            var ref = ref
            repeat {
                refs.append(ref)
                guard ref.header.previous != Block.nullParent else {
                    break
                }
                i += 1
                ref = try _get(ref.header.previous, byID: byID)!
            } while i < count
            return refs
        }
    }

    /// All block storage locators in reverse height order including those for stale/invalid blocks.
    var storageLocators: [BlockStorageLocator] {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            try! byHeight.withCursor(readOnly: true) { cursor in
                var id = try! cursor.get(.last)
                var locators = [BlockStorageLocator]()
                repeat {
                    let ref = try! _get(id!, byID: byID)!
                    if let locator = ref.locator {
                        locators.append(locator)
                    }
                    // Move backwards
                    let maybeID = try! cursor.get(.prevDup)
                    // If no more duplicates for this height, move to previous height
                    if let maybeID {
                        id = maybeID
                    } else {
                        id = try! cursor.get(.prevNodup)
                    }
                } while id != nil
                return locators
            }
        }
    }

    func calculateMissingBlocks(_ ids: [Block.ID]) -> [Block.ID] {
        var missing = [Block.ID]()
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            for id in ids {
                if try byID.get(id) == nil {
                    missing.append(id)
                }
            }
        }
        return missing
    }

    func undo(from tip: BlockRef, backTo ancestor: BlockRef) -> [BlockRef] {
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
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
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
                current = try! _get(current.header.previous, byID: byID)!
            }
            have.append(current.header.id)
            return have
        }
    }

    func undoLastBlock() -> BlockRef {
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

    func findChainForks() async -> [ChainFork] {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            try! byHeight.withCursor(readOnly: true) { cursor in
                var forks = [ChainFork]()
                var maybeID = try! cursor.get(.last)
                while let id = maybeID {
                    let ref = try! _get(id, byID: byID)!
                    var foundBestChild = false
                    for (i, fork) in forks.enumerated() {
                        if fork.start.header.previous == id {
                            forks[i].start = ref
                            foundBestChild = true
                            break
                        }
                    }
                    if !foundBestChild {
                        forks.append(.init(ref))
                        forks.sort { $0 > $1 }
                    }

                    // Move backwards
                    if let nextID = try! cursor.get(.prevDup) {
                        // If no more duplicates for this height, move to previous height
                        maybeID = nextID
                    } else {
                        maybeID = try! cursor.get(.prevNodup)
                    }
                }
                return forks
            }
        }
    }

    func clear() async {
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

    /*
    func get(from startHeight: Int, to endHeight: Int) -> [BlockRef] {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { _, byID, byHeight in
            try (startHeight...endHeight).map { height in
                let blockID = try byHeight.get(height)!
                let data = try byID.get(blockID)!
                return try! BlockRef(data)
            }
        }
    }

    func getParent(for childID: Block.ID) -> BlockRef? {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            let childData = try byID.get(childID)!
            let child = try BlockRef(childData)
            if child.previous == Block.nullParent {
                return BlockRef?.none
            }
            let previousData = try byID.get(child.previous)!
            return try BlockRef(previousData)
        }
    }

    /// Either removes (if header-only) or marks block as invalid
    func removeAll(from height: Int) -> BlockRef {
        let bestHeaderData = try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
        let bestHeight = try byHeight.count - 1
        var refs = [BlockRef]()
            for h in height ... bestHeight {
                let blockID = try byHeight.get(h)!
                let refData = try byID.get(blockID)!
                refs.append(try BlockRef(refData))
            }
            for var ref in refs {
                guard ref.status != .invalid && ref.status != .stale else {
                    continue
                }
                if ref.status == .header {
                    try! byID.delete(ref.header.id)
                } else {
                    // guard let data = try byID.get(ref.blockID) else { return }
                    // var blockRef = try! BlockRef(data)
                    ref.status = .invalid
                    try byID.put(ref.data, key: ref.header.id)
                }
            }
            for h in height ... bestHeight {
                try! byHeight.delete(h)
            }
            let id = try byHeight.get(height - 1)!
            return try byID.get(id)!
        }
        return try! BlockRef(bestHeaderData)
    }
    */
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
