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

    func store(_ block: Block, undo: BlockUndo) throws(BlockStorageError) -> BlockStorageLocator {
        try store(block: block, undo: undo)
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
}
