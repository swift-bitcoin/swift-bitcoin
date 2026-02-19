import Logging

/// Block storage service protocol.
protocol BlockStorage: Sendable {

    var config: BlockStorageConfig { get async }
    var sizeOnDisk: Int { get async }

    var iterator: BlockIterator? { get async }

    init(config: BlockStorageConfig, logger: Logger) async throws(BlockStorageError)

    /// Stores a block together with its undo data
    func storeGenesisBlock(_ block: Block, undo: BlockUndo) async throws(BlockStorageError) -> BlockStorageLocator

    func store(_ block: Block) async throws(BlockStorageError) -> BlockStorageLocator

    func store(_ undo: BlockUndo, forBlockAt locator: BlockStorageLocator) async throws(BlockStorageError) -> BlockStorageLocator

    func retrieve(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> (Block, BlockUndo?)

    func next(_ iterator: BlockIterator) async -> BlockIterator?
    func next(_ iterator: BlockIterator, includeUndo: Bool) async -> BlockIterator?

    func clearUndo() async
    func flush() async
}

struct BlockIterator {
    let locator: BlockStorageLocator
    let block: Block
    let undo: BlockUndo?
}
