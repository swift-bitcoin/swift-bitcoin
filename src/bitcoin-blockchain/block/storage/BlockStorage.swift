import Logging

/// Block storage service protocol.
protocol BlockStorage: Sendable {

    var config: BlockStorageConfig { get async }
    var sizeOnDisk: Int { get async }

    init(config: BlockStorageConfig, logger: Logger) async throws(BlockStorageError)

    /// Stores a block together with its undo data
    func store(_ block: Block, undo: BlockUndo) async throws(BlockStorageError) -> BlockStorageLocator

    func store(_ block: Block) async throws(BlockStorageError) -> BlockStorageLocator

    func store(_ undo: BlockUndo, forBlockAt locator: BlockStorageLocator) async throws(BlockStorageError) -> BlockStorageLocator

    func retrieve(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> (Block, BlockUndo?)
}
