/// Block index service protocol.
protocol BlockIndex: Sendable {

    /// Locators in reverse height order
    var locators: [BlockStorageLocator] { get async }

    /// Most recent header.
    var bestHeader: BlockRef? { get async }

    /// Most recent fully validated block which is an ancestor to the specified header.
    func bestAncestor(of header: BlockRef) async -> BlockRef

    func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus) async throws(BlockIndexError) -> BlockRef

    @discardableResult
    func update(_ id: Block.ID, locator: BlockStorageLocator, status: ValidationStatus) async -> BlockRef

    @discardableResult
    func update(_ id: Block.ID, status: ValidationStatus)  async -> BlockRef

    func has(_ id: Block.ID) async -> Bool
    func get(_ id: Block.ID) async -> BlockRef // TODO: Probably throws and return value nil-able

    func get(at height: Int) async -> BlockRef

    /// For _Median Time Past_ calculation.
    ///
    /// Called from `getMedianTimePast()`
    func get(from header: BlockRef, count: Int) async -> [BlockRef]

    // func get(from startHeight: Int, to endHeight: Int) async -> [BlockRef]

    // Not used at the moment.
    // func getParent(for childID: Block.ID) async -> BlockRef?


    // Not used at the moment
    // /// Either removes (if header-only) or marks block as invalid
    // func removeAll(from height: Int) async -> BlockRef

    /// To check which inventory block items we don't have.
    func calculateMissingBlocks(_ ids: [Block.ID]) async -> [Block.ID]

    func undoLastBlock() async -> BlockRef
}
