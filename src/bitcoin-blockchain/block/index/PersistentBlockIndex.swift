import LMDB
import struct SystemPackage.FilePath
import Foundation
import Logging

/// Database block index service implementation.
actor PersistentBlockIndex: BlockIndex {

    init(path: FilePath, logger: Logger) {
        self.logger = logger
        env = try! Environment(at: URL(filePath: path.appending("block-index").string), maxDBs: 2, pages: 3_000, options: [.noSubDir])
        try! env.createDB(byID)
        try! env.withTransaction(db: .init(byHeightName, options: [.create, .integerKey, .duplicateSort, .duplicateFixed])) { _, _ in }
    }

    private let logger: Logger
    private let env: Environment

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

    func ancestor(of tip: BlockRef, childOf parent: BlockRef) -> BlockRef? {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            var candidate = tip
            while candidate.height > parent.height, candidate.header.previous != parent.header.id {
                candidate = try! _get(candidate.header.previous, byID: byID)!
            }
            return if candidate.header.previous == parent.header.id {
                candidate
            } else {
                nil
            }
        }
    }

    func bestAncestor(of header: BlockRef) -> BlockRef {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            var candidate = header
            while candidate.status != .active {
                candidate = try! _get(candidate.header.previous, byID: byID)!
            }
            precondition(![.stale, .invalid].contains(candidate.status))
            return candidate
        }
    }

    /// Stale of full ancestor
    func bestStaleAncestor(of header: BlockRef) -> BlockRef {
        try! env.withTransaction(db: byID, options: .readOnly) { _, byID in
            var candidate = header
            while ![.stale, .active].contains(candidate.status) {
                candidate = try! _get(candidate.header.previous, byID: byID)!
            }
            return candidate
        }
    }

    @discardableResult
    func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus) throws(BlockIndexError) -> BlockRef {
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
        guard count == 0 || previous != nil else {
            throw BlockIndexError.parentMissing
        }
        let height = if let previous { previous.height + 1 } else { 0 }
        let chainwork = if let previous { previous.chainwork + block.work } else { block.work }
        let chainTxCount = if let previous { previous.chainTxCount + block.txs.count } else { block.txs.count }
        let blockRef = BlockRef(block, height: height, chainwork: chainwork, chainTxCount: chainTxCount, status: status, locator: locator)

        // Add
        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(blockRef.data, key: blockRef.header.id)
            try byHeight.put(blockRef.header.id, key: blockRef.height)
        }
        return blockRef
    }

    func update(_ id: Block.ID, locator: BlockStorageLocator, status: ValidationStatus) -> BlockRef {
        update(id: id, locator: locator, status: status)
    }

    func update(_ id: Block.ID, status: ValidationStatus) -> BlockRef  {
        update(id: id, locator: nil, status: status)
    }

    private func update(id: Block.ID, locator: BlockStorageLocator?, status: ValidationStatus) -> BlockRef {
        let data = try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
            try byID.get(id)!
        }
        var blockRef = try! BlockRef(data)
        if let locator {
            blockRef.locator = locator
        }
        blockRef.status = status
        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(blockRef.data, key: blockRef.header.id)
            try byHeight.put(blockRef.header.id, key: blockRef.height)
        }
        return blockRef
    }

    func get(_ id: Block.ID) -> BlockRef? { // TODO: Probably should throw
        let data = try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
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
        try! env.withTransaction(db: byID, byHeight, options: [.readOnly]) { _, byID, byHeight in
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

    func get(from ref: BlockRef, count: Int) -> [BlockRef] {
        try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in

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
    var blockStorageLocators: [BlockStorageLocator] {
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
        try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
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
                refs.insert(ref, at: 0)
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

    /*
    func get(from startHeight: Int, to endHeight: Int) -> [BlockRef] {
        try! env.withTransaction(db: byID, byHeight, options: [.readOnly]) { _, byID, byHeight in
            try (startHeight...endHeight).map { height in
                let blockID = try byHeight.get(height)!
                let data = try byID.get(blockID)!
                return try! BlockRef(data)
            }
        }
    }

    func getParent(for childID: Block.ID) -> BlockRef? {
        try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
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
