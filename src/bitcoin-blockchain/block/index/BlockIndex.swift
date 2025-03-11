/// Block index service protocol.
protocol BlockIndex: Sendable {

    var height: Int { get async }

    /// Locators in reverse height order
    var locators: [BlockStorageLocator] { get async }
    var lastHeaderID: BlockID { get async }

    @discardableResult
    func add(_ block: TxBlock, locator: BlockStorageLocator? /* = .none */, status: BlockRef.ValidationStatus /* = .header */) async throws(BlockIndexError) -> BlockRef
    func add(_ blockRef: BlockRef) async
    func update(_ id: BlockID, locator: BlockStorageLocator, status: BlockRef.ValidationStatus) async
    func update(_ id: BlockID, status: BlockRef.ValidationStatus) async
    func has(_ id: BlockID) async -> Bool
    func get(_ id: BlockID) async -> BlockRef // TODO: Probably throws and return value nil-able

    func get(at height: Int) async -> BlockRef

    func get(from startHeight: Int, to endHeight: Int) async -> [BlockRef]
    func getParent(for childID: BlockID) async -> BlockRef?

    /// Either removes (if header-only) or marks block as stale
    func removeAll(from height: Int) async -> [BlockRef]
    func calculateMissingBlocks(_ ids: [BlockID]) async -> [BlockID]
}
