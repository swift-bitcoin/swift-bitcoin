/// Block index service protocol.
protocol BlockIndex: Sendable {

    var height: Int { get async }

    /// Locators in reverse height order
    var locators: [BlockStorageLocator] { get async }
    var lastHeaderID: Block.ID { get async }

    @discardableResult
    func add(_ block: Block, locator: BlockStorageLocator? /* = nil */, status: BlockRef.ValidationStatus /* = .header */) async throws(BlockIndexError) -> BlockRef
    func add(_ blockRef: BlockRef) async
    func update(_ id: Block.ID, locator: BlockStorageLocator, status: BlockRef.ValidationStatus) async
    func update(_ id: Block.ID, status: BlockRef.ValidationStatus) async
    func has(_ id: Block.ID) async -> Bool
    func get(_ id: Block.ID) async -> BlockRef // TODO: Probably throws and return value nil-able

    func get(at height: Int) async -> BlockRef

    func get(from startHeight: Int, to endHeight: Int) async -> [BlockRef]
    func getParent(for childID: Block.ID) async -> BlockRef?

    /// Either removes (if header-only) or marks block as stale
    func removeAll(from height: Int) async -> [BlockRef]
    func calculateMissingBlocks(_ ids: [Block.ID]) async -> [Block.ID]
}
