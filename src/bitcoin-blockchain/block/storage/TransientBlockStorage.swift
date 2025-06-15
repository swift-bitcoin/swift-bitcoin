import Foundation
import Collections
// import Logging

// private let logger = Logger(label: "swift-bitcoin.block-storage")

/// Block storage service.
actor TransientBlockStorage: BlockStorage {

    init(config: BlockStorageConfig = .init()) {
        self.config = config
    }

    let config: BlockStorageConfig
    internal private(set) var status = BlockStorageStatus.idle

    private var cache = OrderedDictionary<BlockStorageLocator, Block>()
    private var blocks = [Block]()

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

    func store(_ block: Block) async throws(BlockStorageError) -> BlockStorageLocator {
        let locator: BlockStorageLocator = .init(file: -1, offset: blocks.endIndex)
        blocks.append(block)
        if cache.count == Self.cacheSize - 1 {
            cache.removeFirst()
        }
        cache[locator] = block
        return locator
    }

    func retrieve(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> Block? {
        if let block = cache[locator] {
            return block
        }
        return blocks[locator.offset]
    }

    func remove(_ locator: BlockStorageLocator) {
        // We don't remove blocks from actual storage. The index will get marked as stale outside of this actor. We will just remove from the cache.
        cache.removeValue(forKey: locator)
    }

    static let cacheSize = 3
}
