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
        height = try! env.withTransaction(db: .init(byHeightName, options: [.create, .integerKey])) { _, byHeight in
            try byHeight.count - 1
        }
    }

    let logger: Logger
    private let env: Environment

    /// Active chain height only, includes headers of unverified blocks.
    private(set) var height: Int

    /// Locators in reverse height order
    var locators: [BlockStorageLocator] {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { [height] _, byID, byHeight in
            var locators = [BlockStorageLocator]()
            for i in 0 ... height {
                let h = height - i
                let blockID = try byHeight.get(h)!
                let ref = try BlockRef(try byID.get(blockID)!)
                if let locator = ref.locator {
                    locators.append(locator)
                }
            }
            return locators
        }
    }

    var lastHeaderID: Block.ID {
        precondition(height > -1)
        return try! env.withTransaction(db: byHeight, options: [.readOnly]) { _, db in
            try db.last!
        }
    }

    var chainTip: Block.ID {
        try! env.withTransaction(db: byID, byHeight, options: .readOnly) { [height] _, byID, byHeight in
            for i in 0 ... height {
                let h = height - i
                let blockID = try byHeight.get(h)!
                let ref = try BlockRef(try byID.get(blockID)!)
                if ref.status == .full {
                    return blockID
                }
            }
            preconditionFailure("No fully validated blocks exist")
        }
    }

    @discardableResult
    func add(_ block: Block, locator: BlockStorageLocator?, status: BlockRef.ValidationStatus) throws(BlockIndexError) -> BlockRef {
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
        add(blockRef)
        return blockRef
    }

    func add(_ blockRef: BlockRef) {
        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(blockRef.data, key: blockRef.header.id)
            try byHeight.put(blockRef.header.id, key: blockRef.height)
        }
        height += 1
    }

    func update(_ id: Block.ID, locator: BlockStorageLocator, status: BlockRef.ValidationStatus) {
        update(id: id, locator: locator, status: status)
    }

    func update(_ id: Block.ID, status: BlockRef.ValidationStatus) {
        update(id: id, locator: nil, status: status)
    }

    private func update(id: Block.ID, locator: BlockStorageLocator?, status: BlockRef.ValidationStatus) {
        let data = try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
            try byID.get(id)
        }
        guard let data else { return }
        var blockRef = try! BlockRef(data)
        if let locator {
            blockRef.locator = locator
        }
        blockRef.status = status
        try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
            try byID.put(blockRef.data, key: blockRef.header.id)
            try byHeight.put(blockRef.header.id, key: blockRef.height)
        }
    }

    func has(_ id: Block.ID) -> Bool {
        try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
            try byID.get(id) != nil
        }
    }

    func get(_ id: Block.ID) -> BlockRef { // TODO: Probably throws and return value nil-able
        let data = try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
            try byID.get(id)
        }
        return try! BlockRef(data!)
    }

    func get(at height: Int) -> BlockRef {
        // guard height < byHeight.endIndex else { return nil }
        let data = try! env.withTransaction(db: byID, byHeight, options: [.readOnly]) { _, byID, byHeight in
            let blockID = try byHeight.get(height)!
            return try byID.get(blockID)
        }
        return try! BlockRef(data!)
    }

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

    /// Either removes (if header-only) or marks block as stale
    func removeAll(from height: Int) -> [BlockRef] {
        let (totalRemoved, refs) = try! env.withTransaction(db: byID, byHeight) { _, byID, byHeight in
        var refs = [BlockRef]()
            for h in height ... self.height {
                let blockID = try byHeight.get(h)!
                let refData = try byID.get(blockID)!
                refs.append(try BlockRef(refData))
            }
            for var ref in refs {
                if ref.status < .full {
                    try! byID.delete(ref.header.id)
                } else {
                    // guard let data = try byID.get(ref.blockID) else { return }
                    // var blockRef = try! BlockRef(data)
                    ref.status = .stale
                    try byID.put(ref.data, key: ref.header.id)
                }
            }
            let previousCount = try byHeight.count
            for h in height ... self.height {
                try! byHeight.delete(h)
            }
            return (previousCount - height, refs)
        }
        self.height -= totalRemoved
        return refs
    }

    func calculateMissingBlocks(_ ids: [Block.ID]) -> [Block.ID] {
        var missing = [Block.ID]()
        try! env.withTransaction(db: byID, options: [.readOnly]) { _, byID in
            for id in ids {
                if try byID.get(id) != nil {
                    missing.append(id)
                }
            }
        }
        return missing
    }
}

private let byID = Database.Descriptor("by-id")
private let byHeightName = "by-height"
private let byHeight = Database.Descriptor(byHeightName)
