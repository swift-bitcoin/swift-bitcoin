/// Block storage service protocol.
protocol BlockStorage: Sendable {

    init(config: BlockStorageConfig)

    var config: BlockStorageConfig { get async }
    var status: BlockStorageStatus { get async }
    var sizeOnDisk: Int { get async }

    func start() async throws(BlockStorageError)
    func stop() async
    func store(_ block: Block) async throws(BlockStorageError) -> BlockStorageLocator
    func retrieve(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> Block?
    func remove(_ locator: BlockStorageLocator) async

    static var cacheSize: Int { get }
}
