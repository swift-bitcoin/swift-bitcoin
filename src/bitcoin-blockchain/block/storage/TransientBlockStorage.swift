import Foundation
import Logging
import Collections

/// Block storage service.
actor TransientBlockStorage: BlockStorage {

    init(config: BlockStorageConfig = .init(), logger: Logger) throws(BlockStorageError) {
        precondition(config.path == nil)
        self.config = config
        self.logger = logger
    }

    let config: BlockStorageConfig
    let logger: Logger

    private var blocks = [Block]()
    private var blockUndos = [BlockUndo?]()

    internal private(set) var sizeOnDisk = 0

    func storeGenesisBlock(_ block: Block, undo: BlockUndo) throws(BlockStorageError) -> BlockStorageLocator {
        precondition(blocks.isEmpty)
        return try store(block: block, undo: undo)
    }

    func store(_ block: Block) throws(BlockStorageError) -> BlockStorageLocator {
        try store(block: block, undo: nil)
    }

    func store(_ undo: BlockUndo, forBlockAt locator: BlockStorageLocator) throws(BlockStorageError) -> BlockStorageLocator {
        try store(block: nil, undo: undo, locator: locator)
    }

    private func store(block: Block?, undo: BlockUndo?, locator previousLocator: BlockStorageLocator? = nil) throws(BlockStorageError) -> BlockStorageLocator {
        let blockOffset: Int
        let undoOffset: Int
        if let block {
            blockOffset = blocks.endIndex
            undoOffset = undo == nil ? -1 : blockUndos.endIndex
            blocks.append(block)
            blockUndos.append(undo)
        } else if let undo, let previousLocator {
            blockOffset = previousLocator.offset
            undoOffset = blockOffset // We'll use the same offset for undo data
            blockUndos[undoOffset] = undo
        } else {
            preconditionFailure()
        }
        return .init(file: -1, offset: blockOffset, undoOffset: undoOffset)
    }

    func retrieve(_ locator: BlockStorageLocator) throws(BlockStorageError) -> (Block, BlockUndo?) {
        precondition(locator.file == -1)
        guard blocks.indices.contains(locator.offset) else {
            logger.error("Invalid block offset")
            throw .invalidFileRef
        }
        let undo: BlockUndo?
        if locator.undoOffset != -1 {
            guard blockUndos.indices.contains(locator.undoOffset) else {
                logger.error("Invalid undo offset")
                throw .invalidFileRef
            }
            undo = blockUndos[locator.undoOffset]
        } else {
            undo = nil
        }
        return (blocks[locator.offset], undo)
    }

    var iterator: BlockIterator? {
        next(BlockStorageLocator(file: -1, offset: -1, undoOffset: -1), includeUndo: true)
    }

    func next(_ iterator: BlockIterator) -> BlockIterator? {
        next(iterator.locator, includeUndo: false)
    }

    func next(_ iterator: BlockIterator, includeUndo: Bool) -> BlockIterator? {
        next(iterator.locator, includeUndo: includeUndo)
    }

    func clearUndo() {
        blockUndos = .init()
    }

    private func next(_ locator: BlockStorageLocator, includeUndo: Bool) -> BlockIterator? {
        let offset: Int
        if locator.offset == -1 {
            offset = 0
        } else {
            offset = locator.offset + 1
        }
        guard blocks.indices.contains(offset) else {
            return nil
        }
        let block = blocks[offset]

        let undoOffset: Int
        if locator.offset == -1 {
            undoOffset = blockUndos.isEmpty || !includeUndo ? -1 : 0
        } else {
            undoOffset = locator.undoOffset == -1 || !includeUndo || !blockUndos.indices.contains(locator.undoOffset + 1) ? -1 : locator.undoOffset + 1
        }
        let blockUndo = undoOffset == -1 ? nil : blockUndos[undoOffset]
        let locator = BlockStorageLocator(file: -1, offset: offset, undoOffset: undoOffset)
        return .init(locator: locator, block: block, undo: blockUndo)
    }

    func flush() async { }
}
