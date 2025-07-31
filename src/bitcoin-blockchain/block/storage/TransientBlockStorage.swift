import Foundation
import Collections

/// Block storage service.
actor TransientBlockStorage: BlockStorage {

    init(config: BlockStorageConfig = .init()) {
        self.config = config
    }

    let config: BlockStorageConfig
    internal private(set) var status = BlockStorageStatus.idle

    private var cache = OrderedDictionary<BlockStorageLocator, (Block, BlockUndo)>()
    private var blocks = [Block]()
    private var blockUndos = [BlockUndo]()

    internal private(set) var sizeOnDisk = 0

    func start() async throws(BlockStorageError) {
        status = .starting
        defer { status = .running }
        guard config.path == nil else { return }
    }

    func stop() {
        // status = .stopping
        status = .stopped
    }

    func store(_ block: Block, undo: BlockUndo) async throws(BlockStorageError) -> BlockStorageLocator {
        let locator: BlockStorageLocator = .init(file: blocks.endIndex, offset: -1, undoOffset: -1)
        blocks.append(block)
        blockUndos.append(undo)
        if cache.count == Self.cacheSize - 1 {
            cache.removeFirst()
        }
        cache[locator] = (block, undo)
        return locator
    }

    func retrieve(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> (Block, BlockUndo)? {
        if let block = cache[locator] {
            return block
        }
        return (blocks[locator.file], blockUndos[locator.file])
    }

    static let cacheSize = 3
}
