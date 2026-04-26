/// Block index service protocol.
protocol BlockIndex: Sendable {

    /// Locators in reverse height order.
    var storageLocators: [BlockStorageLocator] { get async }

    /// Valid header/block with the most chainwork.
    var bestHeader: BlockRef? { get async }

    /// Highest fully-validated block in the currently active chain.
    var bestBlock: BlockRef { get async }

    func ancestor(of tip: BlockRef, at height: Int) async -> BlockRef

    /// Most recent fully validated block which is an ancestor to the specified header.
    func bestAncestor(of header: BlockRef) async -> BlockRef

    func lastCommonAncestor(_ blockA: BlockRef, _ blockB: BlockRef) async -> BlockRef

    func missingBlocks(tip: BlockRef, stop: BlockRef, max: Int, exclude: Set<Block.ID>) async -> [Block.ID]

    mutating func addGenesisBlock(_ genesisBlock: Block, locator: BlockStorageLocator) async throws(BlockIndexError) -> BlockRef

    mutating func addHeader(_ header: Block) async throws(BlockIndexError) -> BlockRef

    mutating func updateBlock(_ ref: BlockRef, locator: BlockStorageLocator, status: ValidationStatus, chainTxCount: Int) async -> BlockRef

    mutating func updateHeader(_ ref: BlockRef, locator: BlockStorageLocator) async -> BlockRef

    func get(_ id: Block.ID) async -> BlockRef?

    /// Gets the block reference at the specified height which is part of the active chain.
    func get(at height: Int) async -> BlockRef

    /// Gets all block references at the specified heigh including forks.
    func getAll(at height: Int) async -> [BlockRef]

    /// For _Median Time Past_ calculation.
    ///
    /// Called from `getMedianTimePast()`
    func get(from header: BlockRef, count: Int) async -> [BlockRef]

    /// To check which inventory block items we don't have.
    func calculateMissingBlocks(_ ids: [Block.ID]) async -> [Block.ID]

    /// Find all known chain forks (tips) and return a their start and end block references
    func findChainForks() async -> [ChainFork]

    /// Changes a string of fully validated (acvite) blocks to stale (deactivated).
    /// - Parameters:
    ///   - tip: The best fully validated block to work our way backwards from.
    ///   - ancestor: The ancestor at which to stop (non-inclusive).
    /// - Returns: The deactivated (stale) blocks in descending height order. Use this to revert changes chainstate (coins) one by one.
    mutating func undo(from tip: BlockRef, backTo ancestor: BlockRef) async -> [BlockRef]

    /// Changes a string of stale blocks back to active (full).
    /// - Parameters:
    ///   - tip: The last header to work our way backwards from.
    ///   - ancestor: The ancestor at which to stop (non-inclusive).
    /// - Returns: The reactivated blocks in ascending height order. Use this to reapply changes to chainstate (coins) one by one.
    mutating func reactivate(from tip: BlockRef, backTo ancestor: BlockRef) async -> [BlockRef]

    func makeBlockLocator(from tip: BlockRef) async -> [Block.ID]

    mutating func undoLastBlock() async -> BlockRef

    mutating func clear() async
}
