/// Block index service protocol.
protocol BlockIndex: Sendable {

    /// Locators in reverse height order.
    var blockStorageLocators: [BlockStorageLocator] { get async }

    /// Valid header/block with the most chainwork.
    var bestHeader: BlockRef? { get async }

    /// Highest fully-validated block in the currently active chain.
    var bestBlock: BlockRef { get async }

    func ancestor(of tip: BlockRef, childOf parent: BlockRef) async -> BlockRef?

    /// Most recent fully validated block which is an ancestor to the specified header.
    func bestAncestor(of header: BlockRef) async -> BlockRef

    func bestStaleAncestor(of header: BlockRef) async -> BlockRef

    func add(_ block: Block, locator: BlockStorageLocator?, status: ValidationStatus) async throws(BlockIndexError) -> BlockRef

    @discardableResult
    func update(_ id: Block.ID, locator: BlockStorageLocator, status: ValidationStatus) async -> BlockRef

    @discardableResult
    func update(_ id: Block.ID, status: ValidationStatus)  async -> BlockRef

    func get(_ id: Block.ID) async -> BlockRef?

    /// Gets the block reference at the specified height which is part of the active chain.
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

    /// Changes a string of fully validated (acvite) blocks to stale (deactivated).
    /// - Parameters:
    ///   - tip: The best fully validated block to work our way backwards from.
    ///   - ancestor: The ancestor at which to stop (non-inclusive).
    /// - Returns: The deactivated (stale) blocks in descending height order. Use this to revert changes chainstate (coins) one by one.
    func undo(from tip: BlockRef, backTo ancestor: BlockRef) async -> [BlockRef]

    /// Changes a string of stale blocks back to active (full).
    /// - Parameters:
    ///   - tip: The last header to work our way backwards from.
    ///   - ancestor: The ancestor at which to stop (non-inclusive).
    /// - Returns: The reactivated blocks in ascending height order. Use this to reapply changes to chainstate (coins) one by one.
    func reactivate(from tip: BlockRef, backTo ancestor: BlockRef) async -> [BlockRef]

    func makeBlockLocator(from tip: BlockRef) async -> [Block.ID]

    func undoLastBlock() async -> BlockRef
}
