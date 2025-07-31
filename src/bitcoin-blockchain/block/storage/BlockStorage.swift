/// Block storage service protocol.
protocol BlockStorage: Sendable {

    var config: BlockStorageConfig { get async }
    var status: BlockStorageStatus { get async }
    var sizeOnDisk: Int { get async }

    func start() async throws(BlockStorageError)
    func stop() async
    func store(_ block: Block, undo: BlockUndo) async throws(BlockStorageError) -> BlockStorageLocator
    func retrieve(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> (Block, BlockUndo)?

    static var cacheSize: Int { get }
}
