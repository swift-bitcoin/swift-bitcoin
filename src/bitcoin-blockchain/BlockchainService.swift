import Foundation
import Atomics
import AsyncAlgorithms
import Logging
import _NIOFileSystem
import BitcoinCrypto
import BitcoinBase
import Metrics

/// Notification type for block updates with height and validation status.
public typealias BlockUpdate = (Block, ValidationStatus, Int /* Height */)

/// The blockchain service handles blocks and transactions. It will check transactions before being accepted into the ``mempool`` and it will validate blocks before updating the active chain.
///
/// The blockchain is also responsible for detecting and handling chain reorganizations in a way that does not break consensus.
public actor BlockchainService: Sendable {

    public init(params: ConsensusParams = .regtest, config: Config = .init(), logger: Logger = .init(label: "blockchain")) async throws(InitError) {
        self.params = params
        self.config = config
        switch config.dataLocation {
        case .defaultPath:
            dataDir = FilePath(URL.homeDirectory.relativePath).appending(".swift-bitcoin/data") // TODO: Centralize this logic. Make async with NIOFileSystem and move to start()?
        case .custom(path: let customDataDir):
            let customDataDirPath = FilePath(customDataDir)
            precondition(customDataDirPath.isAbsolute)
            dataDir = customDataDirPath
        default:
            dataDir = nil
        }
        self.logger = logger

        let fm = FileManager.default // TODO: Switch for NIOFileSystem
        if let dataDir {
            do {
                try fm.createDirectory(atPath: dataDir.string, withIntermediateDirectories: true)
            } catch {
                logger.error("There was an issue accessing/creating the specified data directory.")
                throw .dataDirIssue
            }
        }

        blockIndex = if let dataDir { HybridBlockIndex(path: dataDir, logger: logger) } else { TransientBlockIndex() }
        coinIndex = if let dataDir { HybridCoinIndex(path: dataDir, logger: logger) } else { TransientCoinIndex() }

        let config = BlockStorageConfig(path: dataDir, magic: params.magicBytes, maxBlock: ConsensusParams.maxBlockSerializedSized)
        do {
            blockStorage = if dataDir == nil {
                try TransientBlockStorage(config: config, logger: logger)
            } else {
                try await PersistentBlockStorage(config: config, logger: logger)
            }
        } catch {
            logger.error("Could not start block storage.")
            fatalError("Could not start block storage.")
        }
        logger.debug("Indexes and storage initialized.")

        logger.debug("Searching for best header and block…")
        if let bestHeader = await blockIndex.bestHeader {
            self.bestHeader = bestHeader
            if bestHeader.status == .active {
                activeTip = bestHeader
            } else {
                logger.debug("Found best header, now searching for best block…")
                activeTip = await blockIndex.bestBlock
                logger.debug("Highest active block: \(activeTip.header.idHex)")
                // The current best block is just the highest active block which may not actually be an ancestor of the best header, so we might need to check for reorgs.
                // Headers fork, could imply a block reorg
                /*
                let bestAncestor = await blockIndex.bestAncestor(of: bestHeader)
                if bestAncestor.header.id != bestBlock.header.id { … }
                */
                validationTask = Task {
                    try await validateBlocks()
                }
            }
        } else {
            logger.debug("No good header, seeding genesis block")
            let genesisBlock = Block.genesis(params)
            let locator = try! await blockStorage.storeGenesisBlock(genesisBlock, undo: BlockUndo(spentCoins: [])) // TODO: Throw
            activeTip = try! await blockIndex.addGenesisBlock(genesisBlock, locator: locator)
            bestHeader = activeTip
        }
        logger.debug("Best block (tip): \(activeTip.header.idHex)")
        logger.debug("Best header: \(bestHeader.header.idHex)")
    }

    /// Blockchain consensus parameters.
    ///
    /// Use predefined values for each network – e.g. test, main, regtest, …
    public let params: ConsensusParams

    /// Blockchain configuration.
    public let config: Config

    /// The logger instance for blockchain events.
    public let logger: Logger

    /// Path to the data directory where blocks and indices are stored.
    private let dataDir: FilePath?

    /// The block index which includes headers as well as additional information.
    ///
    /// The index also tracks validation status as well as some calculated fields like chainwork.
    ///
    /// Typically the block index is implemented over a key-value storage or database but the blockchain can also be configured to use a transient in-memory version for regression testing, etc.
    private var blockIndex: BlockIndex

    /// The block disk or transient storage which includes block undo (reversal) data.
    private var blockStorage: BlockStorage

    /// The heighest block with "full" validation status.
    private var activeTip: BlockRef

    /// The heighest block/header which could have less than "full" validation status – i.e. header or merkle.
    ///
    /// The best header may be a fork of the active chain which might not include the best block.
    private var bestHeader: BlockRef

    private var heldBlocks = [Block.ID : (Block, BlockStorageLocator?)]()

    /// The memory pool of transactions of _mempool_.
    ///
    /// Transactions that have been accepted into the mempool must have passed all standardness checks and consensus validation both at the time they were first acknowledged as well as after each new block or chain reorganization.
    public private(set) var mempool = [Transaction]()

    /// Available coins for spending. Coins are also referred to as Unspent Transaction Outputs or UTXOs. The current UTXO set is also known as the _chainstate_.
    private var coinIndex: CoinIndex!

    /// Coins generated by mempool transactions.
    private var mempoolCoins = [Outpoint : UnspentOutput]()

    /// Coins spent by mempool transactions.
    private var mempoolExclude = [Outpoint]()

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<BlockUpdate>]()

    /// Subscriptions to new transactions.
    private var txChannels = [AsyncChannel<Transaction>]()

    /// Cache of initial block download status, uses Swift Atomics to copy the behavior of `m_cached_finished_ibd` in Bitcoin Core.
    private var finishedIDB = ManagedAtomic<Bool>(false)

    private var currentlyValidating: Block.ID?
    private var validationTask: Task<(), Swift.Error>? = nil // TODO: Use custom error once `Swift.Task` supports typed throws

    private var reindexing = false
    private var reindexTask: Task<(), Never>? = nil

    /// The height of the best, fully validated block.
    public var height: Int {
        activeTip.height
    }

    /// The height of the best header – i.e. the header with the most accumulated proof-of-work or _chainwork_.
    ///
    /// Note that this is not a header count as there may be orphaned or stale headers. More over an empty blockchain with just the genesis block would imply a `headers` value of 0.
    public var headers: Int {
        bestHeader.height
    }

    /// The identifier (hash) of the best known block. Also referred to as the tip of the blockchain.
    public var chainTip: Block.ID {
        activeTip.header.id
    }

    /// Returns a list of known chain tips across all forks.
    ///
    /// The result includes the active tip and any stale or forked tips discovered in the index.
    /// This property performs an asynchronous search and logs timing information.
    public var chainTips: [ChainTipSummary] { get async {
        let clock = ContinuousClock()
        let start = clock.now

        let result = await blockIndex.findChainForks().map { ChainTipSummary($0) }

        let time = clock.now - start
        logger.info("\(result.count) tips found in \(time)")

        return result
    } }

    /// The genesis block as it is stored on disk.
    public var genesisBlock: Block {
        get async {
            let locator = await blockIndex.get(at: 0).locator!
            let (block, _) = try! await blockStorage.retrieve(locator)
            return block
        }
    }

    /// Whether the blockchain is synchronized with the best header.
    ///
    /// Being synchronized means that the best  known block and the best known header are the same. In other words, the status of the best header is fully validated.
    public var isSynchronized: Bool {
        bestHeader.status == .active
    }

    /// Whether the best header is younger than 24 hours.
    public var hasRecentHeader: Bool {
        bestHeader.header.time > .now.addingTimeInterval(-60 * 60 * 24)
    }

    /// The time of the best block.
    public var time: Date {
        activeTip.header.time
    }

    /// The difficulty of the best block.
    public var difficulty: Double {
        activeTip.difficulty
    }

    /// The median time, calculated using the timestamps of the last 11 blocks starting from the best known block.
    public var medianTime: Date {
        get async {
            await medianTimePast(for: activeTip)
        }
    }

    /// How far along is the blockchain from being fully validated and synchronized.
    public var verificationProgress: Double {
        guessVerificationProgress(activeTip)
    }

    /// Whether the blockchain is in initial block download (IBD) mode.
    ///
    /// IBD status can affect how the node operates and communicates with peers. For instance, it may refrain from validating and relaying transactions until the blockchain is fully synchronized.
    public var isInitialBlockDownload: Bool {
        checkInitialBlockDownload()
    }

    /// Accumulated proof-of-work by the block which has the most.
    public var chainwork: Data {
        Data(activeTip.chainwork.data.reversed())
    }

    /// Size of blocks on disk, including undo data.
    ///
    /// This excludes any related block indices or anything outside the blocks data directory.
    public var sizeOnDisk: Int { get async {
        await blockStorage.sizeOnDisk
    } }

    /// Returns the current UTXO set or _coins_.
    public var unspentOutputs: [Outpoint : UnspentOutput] { get async {
        await coinIndex.coins
    } }

    /// Use ``shutdown()`` to free blockchain resources asynchronously.
    deinit {
        // Intentionally left empty
    }

    /// Cancels concurrent tasks and removes all subscriptions to block and transaction updates.
    public func shutdown() async {

        // Cancel reindex task and wait for it to fishish
        reindexTask?.cancel()
        _ = await reindexTask?.value

        // Cancel validation task and wait for it to fishish
        validationTask?.cancel()
        _ = try? await validationTask?.value

        await blockStorage.flush() // Flush blocks and undo to disk

        // Removes all subscriptions to block and transaction updates.
        for blockChannel in blockChannels {
            unsubscribe(blockChannel)
        }
        for txChannel in txChannels {
            unsubscribe(txChannel)
        }
    }

    /// Processes a block by checking its header and transaction merkle root and then storing it.
    ///
    /// After the merkle root validation the block could be ready for connection to the blockchain. If that's the case, the immediate parameter is used to determine whether the full validation and connection is done on the current `Task` or a new background task.
    public func processBlock(_ block: Block, immediate: Bool = true) async throws(Error) {
        try await processBlock(block, immediate: immediate, locator: nil)
    }

    private func processBlock(_ block: Block, immediate: Bool = true, locator: BlockStorageLocator?) async throws(Error) {

        Metrics.seenBlocksCounter.increment()

        let headerRef: BlockRef
        if let ref = await blockIndex.get(block.id) {
            headerRef = ref
        } else {
            guard let prev = await checkConnectivity(block, locator: locator) else {
                // block was saved for later processing
                return
            }
            headerRef = try await processHeader(block.header, previousHeader: prev)
        }

        switch headerRef.status {
        case .header: try await checkBlock(block, ref: headerRef, locator: locator)
        case .merkle: break
        case .active, .stale: return
        case .invalid: throw .invalidBlockAlreadyExists
        }

        guard currentlyValidating == nil else { return }
        validationTask = Task {
            try await validateBlocks()
        }
        if immediate {
            do {
                try await validationTask?.value
            } catch {
                throw error as! Error // TODO: Remove once `Swift.Task` supports typed throws
            }
        }
    }

    private func nextBlockToValidate() async -> BlockRef? {
        if bestHeader.status == .active {
            return nil
        }
        precondition(bestHeader.height > activeTip.height)

        let nextHeight = activeTip.height + 1
        let nextRefs = await blockIndex.getAll(at: nextHeight)
        let nextChildren = nextRefs.filter { $0.header.previous == activeTip.header.id }

        precondition(!nextChildren.isEmpty)
        // TODO: Failing with multiple connections

        let nextRef: BlockRef
        if nextChildren.count == 1 {
            nextRef = nextChildren[0]
        } else {
            nextRef = await blockIndex.ancestor(of: bestHeader, at: nextHeight)
            precondition(nextRef.header.previous == activeTip.header.id)
        }

        if nextRef.status == .merkle {
            return nextRef
        }
        return nil
    }

    /// Adds a transaction to the mempool.
    ///
    /// Returns silently if transaction is already in the mempool.
    public func addTransaction(_ tx: Transaction) async throws(TransactionValidationError) {

        Metrics.transactionsCounter.increment()

        guard !mempool.contains(tx) else {
            logger.warning("Transaction already in mempool: \(tx.idHex)")
            return
        }

        for txIn in tx.ins {
            // TODO: Have the coins index return transaction's inputs' previous coins/heights all at once (when coins not from the mempool coins array)
            guard let _ = try! await coinIndex.get(txIn.outpoint) ?? mempoolCoins[txIn.outpoint], !mempoolExclude.contains(txIn.outpoint) else {
                logger.warning("Missing UTXO in tx \(tx.idHex)")
                return
            }
        }

        do {
            try await mempoolAcceptPreChecks(tx)
        } catch {
            logger.warning("Mempool precheck failed for tx \(tx.idHex)")
            throw error
        }

        // Check that we have at leat one non-genesis block
        guard activeTip.header.previous != Block.nullParent else {
            logger.warning("Only genesis block exists")
            return
        }

        // TODO:  There's at least 3 occurrences of this "hack" where we create a fake future block only to pass the height
        let nextBlockPlaceholder = BlockRef(.init(previous: activeTip.header.id, merkleRoot: .init(), time: Date.distantPast, target: 0), height: activeTip.height + 1, chainwork: .init(), chainTxCount: -1)
        do {
            try await checkTx(tx, block: nextBlockPlaceholder, previous: activeTip, checkingMempoolAcceptance: true)
        } catch {
            logger.error("Failed transaction check\n\n\(error)")
            return
        }
        mempool.append(tx)

        // Notify other nodes of new tx
        Task {
            await withDiscardingTaskGroup {
                for channel in txChannels {
                    $0.addTask {
                        await channel.send(tx)
                    }
                }
            }
        }

        // Remove coins
        mempoolExclude += tx.ins.map(\.outpoint)
        // Add coins
        let txid = tx.id
        for (i, out) in tx.outs.enumerated() {
            mempoolCoins[.init(tx: txid, out: i)] = .init(out)
        }
    }

    /// Gets a fully validated block by height complete with transactions.
    public func blockID(at height: Int) async -> Block.ID? {
        guard height >= 0, activeTip.height >= height else {
            return nil
        }
        return await blockIndex.get(at: height).header.id
    }

    /// Returns a block header, meaning a block without it's transactions.
    public func header(for id: Block.ID) async -> Block? {
        guard let blockRef = await blockIndex.get(id) else {
            return nil
        }
        return blockRef.header
    }

    /// Gets a fully validated block by height complete with transactions.
    ///
    /// Usually called from unit tests.
    public func block(at height: Int) async -> Block? {
        guard height >= 0, activeTip.height >= height else {
            return nil
        }
        let blockRef = await blockIndex.get(at: height)
        guard let locator = blockRef.locator else {
            return nil
        }
        return if let (block, _) = try? await blockStorage.retrieve(locator) {
            block
        } else { nil }
    }

    /// Gets a fully validated block by ID complete with transactions.
    public func block(for id: Block.ID) async -> Block? {
        guard let blockRef = await blockIndex.get(id), let locator = blockRef.locator, activeTip.height >= blockRef.height else {
            return nil
        }
        return if let (block, _) = try? await blockStorage.retrieve(locator) {
            block
        } else { nil }
    }

    /// Gets a fully validated block by ID complete with transactions.
    public func height(for id: Block.ID) async -> Int? {
        guard let blockRef = await blockIndex.get(id) else {
            return nil
        }
        return blockRef.height
    }

    /// Summarized information about a block.
    public func blockInfo(for id: Block.ID) async -> BlockInfo? {
        guard let ref = await blockIndex.get(id) else {
            return nil
        }
        // TODO: Get all refs at the next height and find the best child by validation status/chainwork (if at least one child exists)
        let refNext = if ref.height < activeTip.height {
            await blockIndex.get(at: ref.height + 1)
        } else {
            BlockRef?.none
        }

        let medianTime = await medianTimePast(for: ref)
        return .init(
            next: refNext?.header.id,
            height: ref.height,
            confirmations: activeTip.height - ref.height + 1,
            status: ref.status,
            difficulty: ref.difficulty,
            chainwork: ref.chainwork.data,
            medianTime: medianTime
        )
    }

    /// Subscribe to block updates from the perspective of the blockchain.
    public func subscribeToBlocks() -> AsyncChannel<BlockUpdate> {
        blockChannels.append(.init())
        return blockChannels.last!
    }

    /// Subscribe to mempool transaction updates.
    public func subscribeToTransactions() -> AsyncChannel<Transaction> {
        txChannels.append(.init())
        return txChannels.last!
    }

    /// Remove a susbcription to block updates.
    public func unsubscribe(_ channel: AsyncChannel<BlockUpdate>) {
        channel.finish()
        blockChannels.removeAll(where: { $0 === channel })
    }

    /// Remove a susbcription to transaction updates.
    public func unsubscribe(_ channel: AsyncChannel<Transaction>) {
        channel.finish()
        txChannels.removeAll(where: { $0 === channel })
    }

    /// Produces a discontinuous list of block hashes in descending height order that may be used to request missing headers from a peer.
    public func blockLocator() async -> [Data] {
        await blockIndex.makeBlockLocator(from: bestHeader)
    }

    /// Finds headers using a discontinuous list of block hashes ordered by descending height.
    public func headers(matching locator: [Data]) async -> [Block] {
        // TODO: Migrate to traversing by `block.previous` as it would be more robust towards reorgs.
        var hitHeight = Int?.none
        for blockID in locator {
            if let ref = await blockIndex.get(blockID) {
                hitHeight = ref.height
                break
            }
        }
        guard let hitHeight else { return [] }
        let maxHeight = activeTip.height
        var heightTo = maxHeight
        let heightFrom = hitHeight + 1
        guard heightFrom <= heightTo else { return [] }
        if heightTo - heightFrom + 1 > 200 {
            heightTo = heightFrom + 199 // The limit is 200 but we are using a closed range
        }
        var headers = [Block]()
        for height in heightFrom ... heightTo {
            let blockRef = await blockIndex.get(at: height)
            headers.append(blockRef.header)
        }
        return headers
    }

    /// Processes a block header without its transactions.
    public func processHeader(_ header: Block) async throws(Error) {
        Metrics.headersCounter.increment()

        guard let prev = await checkConnectivity(header) else {
            return
        }
        _ = try await processHeader(header, previousHeader: prev)
    }

    private func checkConnectivity(_ block: Block, locator: BlockStorageLocator? = nil) async -> BlockRef? {
        guard let previousHeader = await blockIndex.get(block.previous) else {
            heldBlocks[block.id] = (block, locator) // Save header/block for later
            logger.debug("Header \(block.idHex); Previous header not found (holding) \(block.previous.reversed().hex); Held blocks: \(heldBlocks.count)")
            return nil
        }
        return previousHeader
    }

    /// Validates the block header.
    ///
    /// This function contains similar logic to `ContextualCheckBlockHeader()` in Bitcoin Core's `validation.cpp`.
    private func processHeader(_ header: Block, previousHeader: BlockRef) async throws(Error) -> BlockRef {
        precondition(header.txs.isEmpty)

        // Check header

        guard previousHeader.status != .invalid else {
            logger.error("Header \(header.idHex) - part of invalid chain")
            throw .headerPartOfInvalidChain
        }

        // TODO: this really should be `header.time > getMedianTimePast()` (strict comparison) but with only seconds resolution it makes tests generating blocks too fast simply fail. Solution should be to submit new blocks slightly in the future incrementing time by a second each
        guard await header.time >= medianTimePast(for: previousHeader) else {
            logger.error("Header \(header.idHex) - timestamp too old \(header.time)")
            throw .headerTooOld
        }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        guard header.time <= calendar.date(byAdding: .hour, value: 2, to: .now)! else {
            logger.error("Header \(header.idHex) - timestamp too new \(header.time)")
            throw .headerTooNew
        }

        let target = await getNextWorkRequired(lastHeader: previousHeader, newBlockTime: header.time, params: params)
        guard header.target == target else {
            logger.error("Header \(header.idHex) - invalid difficulty target \(header.target)")
            throw .invalidDifficultyTarget
        }

        guard try! DifficultyTarget(header.id) <= DifficultyTarget(compact: header.target) else {
            logger.error("Header \(header.idHex) - insufficient proof of work \(header.target)")
            throw .insuficientProofOfWork
        }

        // Testnet4 and regtest only: Check timestamp against prev for difficulty-adjustment blocks to prevent timewarp attacks (see https://github.com/bitcoin/bitcoin/pull/15482).
        if params.preventBlockStorms {
            // Check timestamp for the first block of each difficulty adjustment interval, except the genesis block.
            if (headers + 1) % params.difficultyAdjustmentInterval == 0 {
                guard header.time.timeIntervalSince1970 >= bestHeader.header.time.timeIntervalSince1970  - ConsensusParams.maxTimewarp else {
                    logger.error("Header \(header.idHex) - potential timewarp attack")
                    throw .timewarpAttack
                }
            }
        }

        // Reject blocks with outdated version
        if header.version < 2 && headers >= params.heightInCoinbaseHeight ||
            (header.version < 3 && headers >= params.strictDERSignatureHeight) ||
            (header.version < 4 && headers >= params.cltvHeight) {
            logger.error("Header \(header.idHex) - unsupported block version \(header.version)")
            throw .unsupportedBlockVersion
        }

        // We can use `try!` because we already checked that the parent exists
        let newHeader = try! await blockIndex.addHeader(header)

        // Apply reorg

        if newHeader.chainwork > bestHeader.chainwork {
            let previousBest = bestHeader
            bestHeader = newHeader
            if newHeader.header.previous != previousBest.header.id {
                // Headers fork, may imply a block reorg
                let bestAncestor = await blockIndex.bestAncestor(of: bestHeader)
                if bestAncestor.header.id != activeTip.header.id {
                    logger.debug("Reorg detected. Switching the active chain…")
                    // Re-org detected

                    // Cancel current validation task
                    if currentlyValidating != nil {
                        validationTask?.cancel()
                        do {
                            try await validationTask?.value
                        } catch {
                            throw error as! Error // TODO: Remove once `Swift.Task` supports typed throws
                        }
                        // NOTE: At this point the active chain may have been extended but the "best ancestor" (highest active block in best header ancestry) should not change
                        precondition(currentlyValidating == nil)
                    }

                    // Deactivate current chain
                    let undoneRefs = await blockIndex.undo(from: activeTip, backTo: bestAncestor)
                    for ref in undoneRefs {
                        try! await undoCoins(ref)
                    }

                    // Reactivate new chain (if previously active)
                    let reactivatedRefs = await blockIndex.reactivate(from: bestHeader, backTo: bestAncestor)
                    for ref in reactivatedRefs {
                        precondition(ref.status == .active)
                        try! await redoCoins(ref)
                    }
                    activeTip = reactivatedRefs.last ?? bestAncestor
                }
            }
        }

        // Look for pending headers to process
        for (h, loc) in heldBlocks.values.filter({ $0.0.previous == header.id }) {
            let ref = try await processHeader(h.header, previousHeader: newHeader)
            if !h.txs.isEmpty {
                try await checkBlock(h, ref: ref, locator: loc)
            }
            heldBlocks[h.id] = nil
        }

        return newHeader
    }

    /// Processes a list of block headers without transactions.
    ///
    /// There may be preexisting headers in the blockchain.
    public func processHeaders(_ headers: [Block]) async throws(Error) {
        for header in headers {
            guard await blockIndex.get(header.id) == nil else {
                // Compact block might send us a known header again
                continue
            }
            try await processHeader(header)
        }
    }

    /// Returns the IDs of the headers missing transactions up to a maximum defined by the function argument.
    public func nextMissingBlocks(max numberOfBlocks: Int) async -> [Block.ID] {
        precondition(numberOfBlocks > 0 && numberOfBlocks <= 1024) // TODO: Get the number of blocks limit from somewhere
        return await blockIndex.missingBlocks(tip: bestHeader, stop: activeTip, max: numberOfBlocks)
    }

    /// Returns multiple fully validated blocks matching the provided IDs.
    public func blocks(matching blockIDs: [Block.ID]) async -> [Block] {
        var ret = [Block]()
        for blockID in blockIDs {
            guard let blockRef = await blockIndex.get(blockID), let locator = blockRef.locator, blockRef.status == .active else {
                continue
            }
            guard let (block, _) = try? await blockStorage.retrieve(locator) else {
                continue
            }
            ret.append(block)
        }
        return ret
    }

    /// Reverts the last block and its effects on the UTXO set.
    public func undoLastBlock() async throws  {
        guard isSynchronized else {
            return
        }
        try await undoCoins(activeTip)
        activeTip = await blockIndex.undoLastBlock()
        bestHeader = activeTip
    }

    private func undoCoins(_ ref: BlockRef) async throws  {
        // TODO: Maybe receive block/undo from caller

        guard let locator = ref.locator else {
            preconditionFailure("The chain tip block must have a disk locator")
        }
        let (block, undo) = try await blockStorage.retrieve(locator)
        guard let undo else { preconditionFailure("Missing block undo data") }
        var outpointsToRemove = [Outpoint]()
        var newCoins = [Outpoint : UnspentOutput]()
        var undoIndex = 0
        for tx in block.txs {
            for input in tx.ins {
                if let coin = undo.spentCoins[undoIndex] {
                    newCoins[input.outpoint] = coin
                }
                undoIndex += 1
            }
            for i in tx.outs.indices {
                outpointsToRemove.append(.init(tx: tx.id, out: i))
            }
        }
        try await coinIndex.update(remove: outpointsToRemove, add: newCoins)
    }

    private func redoCoins(_ ref: BlockRef) async throws  {
        // TODO: Maybe receive block/undo from caller

        guard let locator = ref.locator else {
            preconditionFailure("The chain tip block must have a disk locator")
        }
        let (block, _) = try await blockStorage.retrieve(locator)

        let newBlockHeight = ref.height

        var outpointsToRemove = [Outpoint]()
        for tx in block.txs {
            for input in tx.ins {
                outpointsToRemove.append(input.outpoint)
            }
        }
        var newCoins = [Outpoint : UnspentOutput]()
        for tx in block.txs {
            for (i, out) in tx.outs.enumerated() {
                let outpoint = Outpoint(tx: tx.id, out: i)
                if outpointsToRemove.contains(outpoint) {
                    continue // Spend from the same block
                }
                newCoins[outpoint] = .init(out, height: newBlockHeight, isCoinbase: tx.isCoinbase)
            }
        }
        try! await coinIndex.update(remove: outpointsToRemove, add: newCoins)
    }

    /// Generates a number of new blocks with the coinbase transaction going to the specified script.
    @discardableResult public func generateToScript(_ script: Script, blocks: Int = 1, maxTries: Int = Config.defaultMaxTries, blockTime: Date? = nil) async -> [Block.ID] {
        var ids = [Block.ID]()
        for _ in 0 ..< blocks {
            if let block = await generateTo(script, maxTries: maxTries, blockTime: blockTime ?? .now) {
                ids.append(block.id)
            }
        }
        return ids
    }

    /// Generates a number of new blocks with the coinbase transaction going to the specified public key using standard pay-to-public-key-hash output.
    @discardableResult public func generateTo(_ pubkey: PublicKey, blockTime: Date = .now) async -> Block? {
        logger.info("Generating blocks with coinbase reward going to public key.")
        return await generateTo(Script.payToPubkeyHash(pubkey), blockTime: blockTime)
    }

    /// Generates a block using the mempool transactions and locks the coinbase reward output to the provided public key hash.
    ///
    /// This function essentially mines a block in current thread so it has the potential to completely block. Future versions of this method will provide asynchronous control via detached background task.
    @discardableResult public func generateTo(_ script: Script, initialNonce: Int = 0, maxTries: Int = Config.defaultMaxTries, blockTime: Date = .now, tag: String? = nil, txVersion: Transaction.Version? = nil) async -> Block? {
        logger.info("Generating blocks with coinbase reward going to public key hash.")

        guard isSynchronized else {
            // Waiting for pending block transactions for known headers
            preconditionFailure("Chain cannot contain unvalidated blocks.")
        }
        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)

        let mempoolTxs = mempool

        // Calculate fees
        var totalFees = Amount(0)
        for tx in mempoolTxs {
            totalFees += await calculateFees(tx, auxCoins: mempoolCoins)
        }

        let blockReward = params.blockSubsidy + totalFees
        let coinbaseTx = Transaction.coinbase(version: txVersion, blockHeight: activeTip.height + 1, out: .init(value: blockReward, script: script), witnessMerkleRoot: witnessMerkleRoot, tag: tag)

        let previousBlockHash = activeTip.header.id
        let txs = [coinbaseTx] + mempoolTxs
        let merkleRoot = calculateMerkleRoot(txs)

        let target = await getNextWorkRequired(lastHeader: activeTip, newBlockTime: blockTime, params: params)

        var nonce = initialNonce
        var tries = maxTries
        var block: Block
        repeat {
            block = .init(
                previous: previousBlockHash,
                merkleRoot: merkleRoot,
                time: blockTime,
                target: target,
                nonce: nonce
            )
            nonce += 1
            tries -= 1
        } while tries > 0 && (try! DifficultyTarget(block.id) > DifficultyTarget(compact: target))

        guard try! DifficultyTarget(block.id) <= DifficultyTarget(compact: target) else {
            return nil
        }

        block.txs = txs

        // Process the header and block normally
        try! await processBlock(block, immediate: true)

        // Reset mempool
        mempool = []
        mempoolExclude = []
        mempoolCoins = [:]

        return block
    }

    public func startReindex() async {
        guard !reindexing else {
            precondition(reindexTask != nil)
            logger.info("Re-indexation already in progress")
            return
        }
        logger.info("Starting re-indexation…")
        precondition(reindexTask == nil)
        reindexTask = Task {
            await reindex()
        }
    }

    public var isReindexing: Bool {
        reindexing
    }

    public func stopReindex() async {
        guard reindexing else {
            precondition(reindexTask == nil)
            return
        }
        logger.info("Stopping re-indexation…")
        precondition(reindexTask != nil)
        reindexTask?.cancel()
        Task {
            _ = await reindexTask?.value
            precondition(!reindexing)
            reindexTask = nil
        }
    }

    public func reindex(decodeOnly: Bool = false, headersOnly: Bool = false) async {
        logger.info("Re-indexation started\(decodeOnly ? " (decode only)" : "")\(headersOnly ? " (headers only)" : "")")
        reindexing = true
        defer {
            reindexing = false
        }

        // Cancel validation task and wait for it to fishish
        validationTask?.cancel()
        _ = try? await validationTask?.value

        await coinIndex.clear()
        await blockIndex.clear()
        await blockStorage.clearUndo()

        let clock = ContinuousClock()
        let start = clock.now

        var maybeIt = await blockStorage.iterator
        guard let genesisBlockIterator = maybeIt else {
            logger.warning("No blocks stored")
            return
        }
        precondition(genesisBlockIterator.block.id ==  Block.genesis(params).id)
        precondition(genesisBlockIterator.locator == .init(file: 0, offset: 0, undoOffset: 0))
        do {
            activeTip = try await blockIndex.addGenesisBlock(genesisBlockIterator.block, locator: genesisBlockIterator.locator)
            bestHeader = activeTip
        } catch {
            logger.error("Could not index genesis block.\n\(error)")
            return
        }

        logger.info("Block index, coins, undo data cleared")

        var count = 1
        var lastFileTime = start
        var file = genesisBlockIterator.locator.file

        if Task.isCancelled {
            logger.info("Reindexation cancelled")
            return
        }

        maybeIt = await blockStorage.next(genesisBlockIterator, includeUndo: false)
        while let it = maybeIt/* , count < 10000*/ {
            if it.locator.file != file {
                logger.info("Reindexed file \(file); Blocks: \(count); Time: \(clock.now - lastFileTime); Progress: \(guessVerificationProgress(activeTip))")
                count = 0
                file = it.locator.file
                lastFileTime = clock.now
            }
            count += 1

            if !decodeOnly {
                if headersOnly, let prev = await checkConnectivity(it.block.header, locator: it.locator) {
                    _ = try! await processHeader(it.block.header, previousHeader: prev)
                } else if !headersOnly {
                    try! await processBlock(it.block, immediate: true, locator: it.locator)
                }
            }

            if Task.isCancelled {
                logger.info("Reindexation cancelled")
                return
            }

            maybeIt = await blockStorage.next(it, includeUndo: false)
        }

        let time = clock.now - start
        logger.info("Reindex finished in \(time); Blocks: \(activeTip.height + 1); Headers: \(bestHeader.height + 1)")
    }

    /// Searches the mempool for missing transactions from the provided list.
    public func missingTransactions(matching ids: [Transaction.ID]) async -> [Transaction.ID] {
        var newIDs = ids
        for tx in mempool {
            if ids.contains(tx.id) {
                newIDs.removeAll { $0 == tx.id }
            }
        }
        // TODO: Figure out if we need to look further into confirmed transactions.
        /*
        for locator in await blockIndex.locators {
            guard let (block, _) = try? await blockStorage.retrieve(locator) else {
                continue
            }
            for tx in block.txs {
                if ids.contains(tx.id) {
                    newIDs.removeAll { $0 == tx.id }
                }
            }
        }
        */
        return newIDs
    }

    /// Finds out which of the blocks/headers from the provided list are not yet in the blockchain.
    public func missingBlocks(matching ids: [Block.ID]) async -> [Block.ID] {
        await blockIndex.calculateMissingBlocks(ids)
    }

    /// Gets a transaction by ID looking into mempool and blocks.
    public func transaction(for id: Transaction.ID) async -> Transaction? {
        for tx in mempool {
            if id == tx.id {
                return tx
            }
        }
        for locator in await blockIndex.storageLocators {
            guard let (block, _) = try? await blockStorage.retrieve(locator) else {
                continue
            }
            for tx in block.txs {
                if id == tx.id {
                    return tx
                }
            }
        }
        return nil
    }

    /// Finds transactions in mempool which match any of the provided IDs.
    public func transactions(matching ids: [Transaction.ID]) async -> [Transaction] {
        var ret = [Transaction]()
        for tx in mempool {
            if ids.contains(tx.id) {
                ret.append(tx)
            }
        }
        return ret
    }

    /// Checks mempool for missing transactions.
    public func mempoolTransactions(shortIDs: [UInt64], header: Block, nonce: UInt64) -> [Transaction?] {
        let (first, second) = header.makeShortIDParams(nonce: nonce)
        let mempoolShortIDs = mempool.map { tx in tx.makeShortTxID(nonce: nonce, first: first, second: second)}
        return shortIDs.map { id in
            guard let i = mempoolShortIDs.firstIndex(of: id) else {
                return nil
            }
            return mempool[i]
        }
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``check()``
    private func checkTransactionInputs(_ tx: Transaction, exclude: [Outpoint], auxCoins: [Outpoint : UnspentOutput]) async throws(Transaction.ValidationError) {
        precondition(!tx.isCoinbase)

        let valueIn: Amount
        let nextHeight = activeTip.height + 1

        var valueInAcc = Amount(0)
        for input in tx.ins {
            let outpoint = input.outpoint

            // are the actual inputs available?
            guard let coin = try! await coinIndex.get(outpoint) ?? auxCoins[outpoint], !exclude.contains(outpoint) else {
                throw .inputMissingOrSpent
            }
            guard !coin.isCoinbase || nextHeight - coin.height >= params.coinbaseMaturity else {
                throw .prematureCoinbaseSpend
            }
            valueInAcc += coin.out.value
            guard coin.out.value >= 0 && coin.out.value <= Transaction.maxMoney else {
                throw .inputValueOutOfRange
            }
            guard valueInAcc >= 0 && valueInAcc <= Transaction.maxMoney else {
                throw .inputValueOutOfRange
            }
        }
        valueIn = valueInAcc

        // This is guaranteed by calling Transaction.check() before this function.
        precondition(tx.valueOut >= 0 && tx.valueOut <= Transaction.maxMoney)

        guard valueIn >= tx.valueOut else {
            throw .inputsValueBelowOutput
        }

        let fee = valueIn - tx.valueOut
        guard fee >= 0 && fee <= Transaction.maxMoney else {
            throw .feeOutOfRange
        }
    }

    private func calculateFees(_ tx: Transaction, auxCoins: [Outpoint : UnspentOutput]) async -> Amount {
        precondition(!tx.isCoinbase)
        var valueIn = Amount(0)
        for input in tx.ins {
            let outpoint = input.outpoint

            guard let coin = try! await coinIndex.get(outpoint) ?? auxCoins[outpoint] else {
                preconditionFailure()
            }
            valueIn += coin.out.value
        }
        return valueIn - tx.valueOut
    }

    private func checkTx(_ tx: Transaction, block: BlockRef, previous: BlockRef, checkingMempoolAcceptance: Bool = false, checkScripts: Bool = true, exclude: [Outpoint]? = nil, auxCoins: [Outpoint : UnspentOutput]? = nil) async throws(TransactionValidationError) {
        let exclude = exclude ?? mempoolExclude
        let auxCoins = auxCoins ?? mempoolCoins

        // Check tx
        do {
            try tx.check(weightLimit: ConsensusParams.maxBlockWeight)
            if !tx.isCoinbase {
                try await checkTransactionInputs(tx, exclude: exclude, auxCoins: auxCoins)
            }
        } catch {
            logger.error("Failed transaction check:\n\n\(error)")
            throw .transactionCheckError(error)
        }

        // The block passed is the block in which the transaction exists
        // let blockHeight = block.height + 1

        // Enforce BIP113 (Median Time Past) for block validation only (not mempool acceptance)
        if !checkingMempoolAcceptance {
            let enforceLocktimeMedianTimePast = block.height >= params.csvHeight
            let lockTimeCutoff = if enforceLocktimeMedianTimePast {
                Int(await medianTimePast(for: previous).timeIntervalSince1970)
            } else {
                Int(block.header.time.timeIntervalSince1970)
            }

            // Check that all transactions are finalized
            guard tx.isFinal(blockHeight: block.height, blockTime: lockTimeCutoff) else {
                logger.error("Tx not final: \(tx.idHex)")
                throw .nonFinalTransaction
            }
        }

        if !tx.isCoinbase {
            var prevouts = [TransactionOutput]()
            for input in tx.ins {
                guard let coin = try! await coinIndex.get(input.outpoint) ?? auxCoins[input.outpoint] /*, !exclude.contains(input.outpoint) */ else {
                    preconditionFailure() // Already checked in checkTransactionInputs
                }
                prevouts.append(coin.out)
            }
            guard checkScripts else { return }
            if !tx.verifyScripts(prevouts: prevouts, config: checkingMempoolAcceptance ? .standard : .mandatory) {
                logger.error("Failed script validation")
                throw .scriptError
            }
        }
    }

    /// Checks if a mempool transaction still has all it's inputs available.
    private func inputsAvailable(_ tx: Transaction, exclude: [Outpoint], auxCoins: [Outpoint : UnspentOutput]) async -> Bool {
        precondition(!tx.isCoinbase)
        for input in tx.ins {
            let outpoint = input.outpoint
            // are the actual inputs available?
            guard let _ = try! await coinIndex.get(outpoint) ?? auxCoins[outpoint], !exclude.contains(outpoint) else {
                return false
            }
        }
        return true
    }

    /// Processes a block complete with transactions.
    ///
    /// If it is the first time we see this block, its header will be processed first.
    /// If the block builds on the acvite chain tip, it will be connected thus validating its transactions.
    /// Otherwise the index will be updated to reflect that the merkle root has been verified.
    @discardableResult private func checkBlock(_ block: Block, ref blockRef: BlockRef, locator: BlockStorageLocator? = nil) async throws(Error) -> BlockRef {
        logger.debug("Processing block \(block.idHex)")

        // Check block

        // Verify coinbase
        guard let coinbaseTx = block.txs.first, coinbaseTx.isCoinbase else {
            logger.error("Empty transactions or missing/mispositioned coinbase transaction")
            throw .missingCoinbaseTransaction
        }

        // Verify merkle root
        let expectedMerkleRoot = calculateMerkleRoot(block.txs)
        guard block.merkleRoot == expectedMerkleRoot else {
            logger.error("Wrong merkle root")
            throw .wrongMerkleRoot
        }

        logger.debug("Processing block txs \(block.idHex)")

        guard blockRef.status == .header else {
            logger.warning("Block \(block.idHex) already exists with status \(blockRef.status)")
            // throw .blockAlreadyExists
            return blockRef
        }

        logger.debug("Block \(block.idHex) merkle status validated")

        // Store block

        let updatedRef: BlockRef
        do {
            let locator = if let locator {
                locator
            } else {
                try await blockStorage.store(block)
            }
            updatedRef = await blockIndex.updateHeader(blockRef, locator: locator)
            if updatedRef.header.id == bestHeader.header.id {
                bestHeader = updatedRef
            }
        } catch {
            logger.error("Could not save block to disk")
            throw .blockFileIssue
        }
        logger.debug("Block \(block.idHex) saved to disk without undo data")

        // Notify other nodes of new validation status
        Task {
            await withDiscardingTaskGroup {
                for channel in blockChannels {
                    $0.addTask {
                        await channel.send((block, updatedRef.status, updatedRef.height))
                    }
                }
            }
        }

        return updatedRef
    }

    private func validateBlocks() async throws(Error) {
        var maybeNext: BlockRef? = await nextBlockToValidate()
        while let next = maybeNext {
            currentlyValidating = next.header.id
            try await connectBlock(next)
            guard !Task.isCancelled else {
                break // Break while-loop otherwise could be stuck trying to connect same block over and over
            }
            maybeNext = await nextBlockToValidate()
        }
        currentlyValidating = nil
    }

    /// If we have a header in our index it updates it's validation. If not it adds the block to the index. Adds the block to storage along with undo information and updates coins (chainstate).
    private func connectBlock(_ blockRef: BlockRef) async throws(Error) {
        // precondition(cachedBlock != nil || blockRef != nil)
        //let blockID = cachedBlock?.id ?? blockRef!.header.id
        let blockID = blockRef.header.id

        /*
        let blockRef = if let blockRef {
            blockRef
        } else {
            await blockIndex.get(blockID)!
        }*/

        precondition(blockRef.header.previous != Block.nullParent) // Can't be genesis block
        precondition(blockRef.header.id == blockID && blockRef.status == .merkle)
        guard let blockOnlyLocator = blockRef.locator else {
            preconditionFailure()
        }
        precondition(blockOnlyLocator.undoOffset == -1)

        let block: Block
        /*if let cachedBlock {
            block = cachedBlock
        } else {*/
            do {
                (block, _) = try await blockStorage.retrieve(blockOnlyLocator)
            } catch {
                throw .blockFileIssue
            }
        /*}*/

        logger.debug("Connecting block \(block.idHex)")

        let startTime = ContinuousClock.Instant.now

        let scriptCheckReason: String?
        if let assumeValid = params.assumeValid {
            if let assumeValidRef = await blockIndex.get(assumeValid) {
                if await blockIndex.ancestor(of: assumeValidRef, at: blockRef.height).header.id != blockRef.header.id {
                    scriptCheckReason = blockRef.height > assumeValidRef.height ? "block height above assumevalid height" : "block not in assumevalid chain"
                } else if await blockIndex.ancestor(of: bestHeader, at: blockRef.height).header.id != blockRef.header.id {
                    scriptCheckReason = "block not in best header chain"
                } else if try! DifficultyTarget(Data(params.minChainwork.reversed())) > bestHeader.chainwork {
                    scriptCheckReason = "best header chainwork below minimumchainwork"
                } else if blockProofEquivalentTime(to: bestHeader, from: blockRef, tip: bestHeader) <= 60 * 60 * 24 * 7 * 2 {
                    scriptCheckReason = "block too recent relative to best header";
                } else {
                    scriptCheckReason = nil
                }
            } else {
                scriptCheckReason = "assumevalid hash not in headers"
            }
        } else {
            scriptCheckReason = "assumevalid=0 (always verify)"
        }

        if let scriptCheckReason {
            logger.info("Checking scripts validation due to \(scriptCheckReason)")
        } else {
            logger.info("Skipping script validation due to assume valid configuration")
        }

        // Enforce BIP68 (sequence locks)
        let verifyLockTimeSequence = blockRef.height >= params.csvHeight

        var fees = Amount(0)
        var tmpExclude = [Outpoint]()
        var tmpCoins = [Outpoint: UnspentOutput]()
        for txIndex in block.txs.indices {
            guard !Task.isCancelled else { return }
            let tx = block.txs[txIndex]
            do {
                try await checkTx(tx, block: blockRef, previous: activeTip, checkScripts: scriptCheckReason != nil, exclude: tmpExclude, auxCoins: tmpCoins)
            } catch {

                // TODO: Invalidate all descendants (blocks that build upon this block)
                logger.error("Invalid transaction #\(txIndex) in block \(block.idHex)\n\n\(error)")
                throw .invalidTransactionInBlock(error)
            }
            if !tx.isCoinbase {
                fees += await calculateFees(tx, auxCoins: tmpCoins)

                // Check that transaction is BIP68 final
                // BIP68 lock checks (as opposed to nLockTime checks) must be in ConnectBlock because they require the UTXO set
                var previousHeights = await calculatePrevHeights(tx, tip: activeTip, excludeCoins: tmpExclude, auxCoins: tmpCoins)
                try await sequenceLocks(tx, block: blockRef, previous: activeTip, verifyLockTimeSequence: verifyLockTimeSequence, previousHeights: &previousHeights)
            }
            // Remove coins
            tmpExclude += tx.ins.map(\.outpoint)
            // Add coins
            let txid = tx.id
            for (i, out) in tx.outs.enumerated() {
                tmpCoins[.init(tx: txid, out: i)] = .init(out, isCoinbase: tx.isCoinbase)
            }
        }

        // Check coinbase
        let coinbaseTx = block.txs[0]
        let blockReward = getBlockSubsidy(blockRef.height) + fees
        // We allow for a portion of the block reward to be left unclaimed.
        guard blockReward >= coinbaseTx.valueOut else {
            logger.error("Coinbase transaction overspends for block \(block.idHex)")
            throw .coinbaseTransactionOverspends
        }

        let unclaimed = blockReward - coinbaseTx.valueOut
        precondition(unclaimed >= 0 && unclaimed <= Transaction.maxMoney) // coinbase "fee" our of range, can this ever happen??

        // Will now update chain tip and coins
        let newBlockHeight = activeTip.height + 1

        var outpointsToRemove = [Outpoint]()
        for tx in block.txs {
            for input in tx.ins {
                outpointsToRemove.append(input.outpoint)
            }
        }
        var newCoins = [Outpoint : UnspentOutput]()
        for tx in block.txs {
            for (i, out) in tx.outs.enumerated() {
                let outpoint = Outpoint(tx: tx.id, out: i)
                if outpointsToRemove.contains(outpoint) {
                    continue // Spend from the same block
                }
                newCoins[outpoint] = .init(out, height: newBlockHeight, isCoinbase: tx.isCoinbase)
            }
        }

        // Last chance to exit before modifying coins, mempool, activeTip
        guard !Task.isCancelled else { return }

        let spentCoins = try! await coinIndex.update(remove: outpointsToRemove, add: newCoins)
        let blockUndo = BlockUndo(spentCoins: spentCoins)

        // Clean up mempool and mempoolCoins
        var newMempool = [Transaction]()
        var mpExclude = [Outpoint]()
        var mpCoins = [Outpoint: UnspentOutput]()
        for tx in mempool {
            if await inputsAvailable(tx, exclude: mpExclude, auxCoins: mpCoins) {
                newMempool.append(tx)
            } else {
                logger.debug("Removing tx from mempool: \(tx.idHex)")
                continue
            }
            // Remove coins
            mpExclude += tx.ins.map(\.outpoint)
            // Add coins
            let txid = tx.id
            for (i, out) in tx.outs.enumerated() {
                mpCoins[.init(tx: txid, out: i)] = .init(out)
            }
        }
        mempool = newMempool
        mempoolExclude = mpExclude
        mempoolCoins = mpCoins

        // Update best block and header
        let newLocator = try! await blockStorage.store(blockUndo, forBlockAt: blockOnlyLocator) // TODO: throw

        activeTip = await blockIndex.updateBlock(blockRef, locator: newLocator, status: .active, chainTxCount: activeTip.chainTxCount + block.txs.count)

        if !reindexing {
            logger.info("New tip: \(block.idHex)")
        }

        // Notify other nodes of new tip
        Task { [ status = activeTip.status, height = activeTip.height] in
            await withDiscardingTaskGroup {
                for channel in blockChannels {
                    $0.addTask {
                        await channel.send((block, status, height))
                    }
                }
            }
        }

        Metrics.validBlocksCounter.increment()
        Metrics.validTransactionsCounter.increment(by: block.txs.count)
        Metrics.blockValidationTimer.record(duration: .now - startTime)

        if bestHeader.header.id == activeTip.header.id {
            bestHeader = activeTip
        }
    }

    private func getNextWorkRequired(lastHeader: BlockRef, newBlockTime: Date, params: ConsensusParams) async -> Int {
        let heightLast = lastHeader.height
        precondition(heightLast >= 0)
        let powLimitTarget = try! DifficultyTarget(Data(params.powLimit.reversed()))
        let proofOfWorkLimit = powLimitTarget.toCompact()

        // Only change once per difficulty adjustment interval
        if (heightLast + 1) % params.difficultyAdjustmentInterval != 0 {
            if params.powAllowMinDifficultyBlocks {
                // Special difficulty rule for testnet:
                // If the new block's timestamp is more than 2 * 10 minutes then allow mining of a min-difficulty block.
                if Int(newBlockTime.timeIntervalSince1970) > Int(lastHeader.header.time.timeIntervalSince1970) + params.powTargetSpacing * 2 {
                    return proofOfWorkLimit
                } else {

                    // TODO: - Traverse back from last header
                    ///
                    /// ```cpp
                    /// const CBlockIndex* pindex = pindexLast;
                    /// while (pindex->pprev && pindex->nHeight % params.DifficultyAdjustmentInterval() != 0 && pindex->nBits == nProofOfWorkLimit)
                    ///     pindex = pindex->pprev;
                    /// return pindex->nBits;
                    /// ```

                    // Return the last non-special-min-difficulty-rules-block
                    var height = heightLast
                    var header = lastHeader
                    while height > 0 && height % params.difficultyAdjustmentInterval != 0 && header.header.target == proofOfWorkLimit {
                        height -= 1
                        header = await blockIndex.get(at: height)
                    }
                    return header.header.target
                }
            }
            return lastHeader.header.target
        }

        // Go back by what we want to be 14 days worth of blocks
        let heightFirst = heightLast - (params.difficultyAdjustmentInterval - 1)
        precondition(heightFirst >= 0)
        let firstHeader = await blockIndex.ancestor(of: lastHeader, at: heightFirst)
        return await calculateNextWorkRequired(lastHeader: lastHeader, firstBlockTime: firstHeader.header.time, params: params)
    }

    private func calculateNextWorkRequired(lastHeader: BlockRef, firstBlockTime: Date, params: ConsensusParams) async -> Int {
        if params.powNoRetargeting {
            return lastHeader.header.target
        }

        // Limit adjustment step
        var actualTimespan = Int(lastHeader.header.time.timeIntervalSince1970) - Int(firstBlockTime.timeIntervalSince1970)
        if actualTimespan < params.powTargetTimespan / 4 {
            actualTimespan = params.powTargetTimespan / 4
        }
        if actualTimespan > params.powTargetTimespan * 4 {
            actualTimespan = params.powTargetTimespan * 4
        }

        // Retarget
        let powLimitTarget = try! DifficultyTarget(Data(params.powLimit.reversed()))

        var new: DifficultyTarget
        if params.preventBlockStorms {

            // TODO: - Use `BlockIndex.ancestor(of:at:)` instead of `get(at:)`
            ///
            /// ```cpp
            /// int nHeightFirst = pindexLast->nHeight - (params.DifficultyAdjustmentInterval()-1);
            /// const CBlockIndex* pindexFirst = pindexLast->GetAncestor(nHeightFirst);
            /// bnNew.SetCompact(pindexFirst->nBits);
            /// ```

            // Here we use the first block of the difficulty period. This way the real difficulty is always preserved in the first block as it is not allowed to use the min-difficulty exception.
            let heightFirst = lastHeader.height - (params.difficultyAdjustmentInterval - 1)
            let first = await blockIndex.get(at: heightFirst)
            new = DifficultyTarget(compact: first.header.target)
        } else {
            new = DifficultyTarget(compact: lastHeader.header.target)
        }
        precondition(!new.isZero)
        new *= (UInt32(actualTimespan))
        new /= DifficultyTarget(UInt64(params.powTargetTimespan))

        if new > powLimitTarget { new = powLimitTarget }

        return new.toCompact()
    }

    private func getBlockSubsidy(_ height: Int) -> Amount {
        let halvings = height / params.subsidyHalvingInterval
        // Force block reward to zero when right shift is undefined.
        if halvings >= 64 {
            return 0
        }

        var subsidy = params.blockSubsidy
        // Subsidy is cut in half every 210,000 blocks which will occur approximately every 4 years.
        subsidy >>= halvings
        return subsidy
    }

    /// Median time past. The median of the last 11 blocks.
    ///
    /// BIP113
    private func medianTimePast(for header: BlockRef) async -> Date {
        let blockRefs = await blockIndex.get(from: header, count: 11)
        let median = blockRefs.map(\.header.time).sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }


    /// Verification progress of the best block known so far.
    ///
    /// This function could be adapted to return the verification progress for any arbitrary block.
    private func guessVerificationProgress(_ block: BlockRef) -> Double {

        let data = params.chainData

        if block.chainTxCount == -1 {
            logger.debug("Block \(block.header.idHex) has unset m_chain_tx_count. Unable to estimate verification progress.")
            return 0
        }

        let now = nowSeconds()

        let blockTime = if abs(now - block.header.time.timeIntervalSince1970) <= 2 * 60 * 60 && bestHeader.height >= block.height {
            // When the header is known to be recent, switch to a height-based approach. This ensures the returned value is quantized when close to "1.0", because some users expect it to be. This also  avoids relying too much on the exact miner-set timestamp, which may be off.
            now - Double(bestHeader.height - block.height) * Double(params.powTargetSpacing)
        } else {
            block.header.time.timeIntervalSince1970
        }

        let chainDataTime = TimeInterval(data.time)

        let txTotal = if block.chainTxCount <= data.txCount {
            Double(data.txCount) + (now - chainDataTime) * data.txRate
        } else {
            Double(block.chainTxCount)  + (now - blockTime) * data.txRate
        }
        return min(Double(block.chainTxCount) / txTotal, 1.0)
    }

    /// Whether we are in Initial Block Download (IBD) mode.
    ///
    /// Note that though this function is non-mutating, we may end up modifying `finishedIDB`, which is a performance-related implementation detail.
    ///
    /// This function is similar to `ChainstateManager::IsInitialBlockDownload()` in Bitcoin Core (`validation.cpp`).
    private func checkInitialBlockDownload() -> Bool {

        // Optimization: pre-test latch before taking the lock.
        if finishedIDB.load(ordering: .relaxed) { return false }

        // Currently this function is never called before the blockchain service has started which includes the initialization of the block storage. The process could become more async in the future so leaving the below line commented out for now.
        // if await blockStorage.status == .starting { return true }

        if try! DifficultyTarget(params.minChainwork.reversed()) > activeTip.chainwork { return true }

        let maxTipAge = TimeInterval(24 * 60 * 60) // 24 hours
        let maxTipTime = Date(timeIntervalSince1970: nowSeconds() - maxTipAge)
        if (activeTip.header.time < maxTipTime ) { return true }

        logger.info("Leaving InitialBlockDownload (latching to false)")
        finishedIDB.store(true, ordering: .relaxed)
        return false
    }

    /// A helper which calculates heights of inputs of a given transaction.
    ///
    /// Called from `connectBlock()` and `calculateLockPointsAtTip()`.
    ///
    /// - parameter tip The current chain tip. If an input belongs to a mempool
    ///                   transaction, we assume it will be confirmed in the next block.
    /// - parameter tx The transaction being evaluated.
    ///
    /// - returns A vector of input heights or nil, in case of an error.
    private func calculatePrevHeights(_ tx: Transaction, tip: BlockRef, excludeCoins: [Outpoint], auxCoins: [Outpoint : UnspentOutput]) async -> [Int] {
        var prevHeights = [Int]() // tx.ins.count
        for txIn in tx.ins {
            // TODO: Have the coins index return transaction's inputs' previous coins/heights all at once (when coins not from the mempool coins array)
            guard let coin = try! await coinIndex.get(txIn.outpoint) ?? auxCoins[txIn.outpoint], !excludeCoins.contains(txIn.outpoint) else {
                preconditionFailure() // Missing input in transaction
            }
            if coin.isMempool {
                // Assume all mempool transaction confirm in the next block
                prevHeights.append(tip.height + 1)
            } else {
                prevHeights.append(coin.height)
            }
        }
        return prevHeights
    }

    /// Called from `mempoolAcceptPreChecks()`
    private func calculateLockPointsAtTip(_ tx: Transaction, tip: BlockRef) async -> LockPoints {

        var prevHeights = await calculatePrevHeights(tx, tip: tip, excludeCoins: mempoolExclude, auxCoins: mempoolCoins)

        /// TODO: this relies on `BlockIndex.get(count:)` and `BlockIndex.ancestor(at:)` not looking up the tip parameter within the index as it will not be found there, being a dummy placeholder. Possible fix is to pass only the next height and previous block ID to `calculateSequenceLocks()`
        let nextTip = BlockRef(.init(previous: tip.header.id, merkleRoot: .init(), time: Date(timeIntervalSince1970: 0), target: 0), height: tip.height + 1, chainwork: .init(), chainTxCount: -1)

        // When SequenceLocks() is called within ConnectBlock(), the height
        // of the block *being* evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the
        // *next* block, we need to use one more than active_chainstate.m_chain.Height()
        let (minHeight, minTime) = await calculateSequenceLocks(tx, block: nextTip, verifyLockTimeSequence: true /* STANDARD_LOCKTIME_VERIFY_FLAGS */, previousHeights: &prevHeights)

        // Also store the hash of the block with the highest height of all the blocks which have sequence locked prevouts.
        // This hash needs to still be on the chain for these LockPoint calculations to be valid
        // Note: It is impossible to correctly calculate a maxInputBlock if any of the sequence locked inputs depend on unconfirmed txs, except in the special case where the relative lock time/height is 0, which is equivalent to no sequence lock. Since we assume input height of tip+1 for mempool txs and test the resulting min_height and min_time from CalculateSequenceLocks against tip+1.
        var maxInputHeight = 0
        for height in prevHeights {
            // Can ignore mempool inputs since we'll fail if they had non-zero locks
            if height != nextTip.height {
                maxInputHeight = max(maxInputHeight, height)
            }
        }

        // tip->GetAncestor(max_input_height) should never return a nullptr because max_input_height is always less than the tip height. It would, however, be a bad bug to continue execution, since a LockPoints object with the maxInputBlock member set to nullptr signifies no relative lock time.
        let ancestor = await blockIndex.ancestor(of: tip, at: maxInputHeight)
        return (minHeight, minTime, ancestor)
    }

    /// This function is equivalent to `CheckFinalTxAtTip()` in Bitcoin Core (`validation.h`) which is itself called by `MemPoolAccept::PreChecks()`
    ///
    /// BIP113
    private func checkFinalTxAtTip(_ tx: Transaction, activeChainTip: BlockRef) async -> Bool {

        // CheckFinalTxAtTip() uses active_chain_tip.Height() + 1 to evaluate nLockTime because when IsFinalTx() is called within AcceptBlock(), the height of the block *being* evaluated is what is used. Thus if we want to know if a transaction can be part of the *next* block, we need to call IsFinalTx() with one more than active_chain_tip.Height().
        let blockHeight = activeChainTip.height + 1

        // BIP113 requires that time-locked transactions have nLockTime set to less than the median time of the previous block they're contained in.
        // When the next block is created its previous block will be the current chain tip, so we use that to calculate the median time passed to IsFinalTx().
        let blockTimeDate = await medianTimePast(for: activeChainTip)
        let blockTime = Int(blockTimeDate.timeIntervalSince1970)

        return tx.isFinal(blockHeight: blockHeight, blockTime: blockTime)
    }

    /// Run the policy checks on a given transaction, excluding any script checks.
    /// Looks up inputs, calculates feerate, considers replacement, evaluates package limits, etc. As this function can be invoked for "free" by a peer, only tests that are fast should be done here (to avoid CPU DoS).
    private func mempoolAcceptPreChecks(_ tx: Transaction) async throws(TransactionValidationError) {

        // Only accept nLockTime-using transactions that can be mined in the next
        // block; we don't want our mempool filled up with transactions that can't
        // be mined yet.
        guard await checkFinalTxAtTip(tx, activeChainTip: activeTip) else {
            logger.error("Invalid transaction \(tx.idHex): Premature spend, non-final")
            throw .nonFinalTransaction
        }

        // Only accept BIP68 sequence locked transactions that can be mined in the next
        // block; we don't want our mempool filled up with transactions that can't
        // be mined yet.
        // Pass in m_view which has all of the relevant inputs cached. Note that, since m_view's
        // backend was removed, it no longer pulls coins from the mempool.
        let lockPoints = await calculateLockPointsAtTip(tx, tip: activeTip)
        do {
            try await checkSequenceLocksAtTip(activeTip, lockPoints: lockPoints)
        } catch {
            logger.error("Invalid transaction \(tx.idHex): Premature spend, BIP68 non-final")
            throw .nonFinalTransaction
         }
    }

    /// Checks if the transaction will be final in the next block to be created on top of the new chain.
    ///
    /// This function is equivalent to `CheckSequenceLocksAtTip()` in Bitcoin Core (`validation.h`) which is itself called by `MemPoolAccept::PreChecks()`.
    ///
    ///  Called by `mempoolAcceptPreChecks()`.
    ///
    /// BIP68
    private func checkSequenceLocksAtTip(_ tip: BlockRef, lockPoints: LockPoints) async throws(Error) {
        // checkSequenceLocksAtTip() uses chainActive.Height()+1 to evaluate height based locks because when SequenceLocks() is called within ConnectBlock(), the height of the block *being* evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the *next* block, we need to use one more than chainActive.Height()

        /// TODO: this relies on `BlockIndex.get(count:)` and `BlockIndex.ancestor(at:)` not looking up the tip parameter within the index as it will not be found there, being a dummy placeholder. Possible fix is to pass only the next height and previous block ID to `calculateSequenceLocks()`
        let nextBlockPlaceholder = BlockRef(.init(previous: tip.header.id, merkleRoot: .init(), time: Date(timeIntervalSince1970: 0), target: 0), height: tip.height + 1, chainwork: .init(), chainTxCount: -1)

        try await evaluateSequenceLocks(nextBlockPlaceholder, previous: tip, lockPair: (lockPoints.height, lockPoints.time))
    }

    /// Called by `BlockchainService.connectBlock()`.
    ///
    /// BIP68
    private func sequenceLocks(_ tx: Transaction, block: BlockRef, previous: BlockRef, verifyLockTimeSequence: Bool, previousHeights: inout [Int]) async throws(Error) {
        try await evaluateSequenceLocks(block, previous: previous, lockPair: await calculateSequenceLocks(tx, block: block, verifyLockTimeSequence: verifyLockTimeSequence, previousHeights: &previousHeights))
    }

    /// Calculates the block height and previous block's median time past at which the transaction will be considered final in the context of BIP 68.
    ///
    /// Also removes from the vector (sets to 0) of input heights any entries which did not correspond to sequence locked inputs as they do not affect the calculation.
    ///
    /// The block reference may be a placeholder reference to a potential new chain tip which will only be used to access ancestors.
    ///
    /// Called from `sequenceLocks()`.
    ///
    /// BIP68
    private func calculateSequenceLocks(_ tx: Transaction, block: BlockRef, verifyLockTimeSequence: Bool, previousHeights: inout [Int]) async -> LockPair {

        precondition(previousHeights.count == tx.ins.count);

        precondition(block.height >= 0 && block.header.time >= Date.distantPast)
        // Warning: `block` may or may not not be a valid reference from our block index. It could also be a placeholder for the next block with only valid height and previous.

        // Will be set to the equivalent height- and time-based nLockTime values that would be necessary to satisfy all relative lock-time constraints given our view of block chain history.
        // The semantics of nLockTime are the last invalid height/time, so use -1 to have the effect of any height or time being valid.
        var minHeight = -1;
        var minTime = -1;

        // tx.nVersion is signed integer so requires cast to unsigned otherwise we would be doing a signed comparison and half the range of nVersion wouldn't support BIP68.
        let enforceBIP68 = tx.version >= .v2 && verifyLockTimeSequence

        // Do not enforce sequence numbers as a relative lock time unless we have been instructed to
        guard enforceBIP68 else { return (minHeight, minTime) }

        for (inIndex, input) in tx.ins.enumerated() {

            // Sequence numbers with the most significant bit set are not treated as relative lock-times, nor are they given any consensus-enforced meaning at this point.
            if input.sequence.isLocktimeDisabled {
                // The height of this input is not relevant for sequence locks
                previousHeights[inIndex] = 0
                continue
            }

            let coinHeight = previousHeights[inIndex]

            if let locktimeSeconds = input.sequence.locktimeSeconds {

                // NOTE: Subtract 1 to maintain nLockTime semantics
                // BIP68 relative lock times have the semantics of calculating the first block or time at which the transaction would be valid. When calculating the effective block time or height for the entire transaction, we switch to using the semantics of nLockTime which is the last invalid block time or height.  Thus we subtract 1 from the calculated time or height.
                let ancestor = await blockIndex.ancestor(of: block, at: max(coinHeight - 1, 0))
                let coinTimeDate = await medianTimePast(for: ancestor)
                let coinTime = Int(coinTimeDate.timeIntervalSince1970)

                // Time-based relative lock-times are measured from the smallest allowed timestamp of the block containing the txout being spent, which is the median time past of the block prior.
                minTime = max(minTime, coinTime + locktimeSeconds - 1)
            } else if let locktimeBlocks = input.sequence.locktimeBlocks {
                minHeight = max(minHeight, coinHeight + locktimeBlocks - 1)
            } else {
                preconditionFailure() // `input.sequence.isLocktimeDisabled == false`
            }
        }
        return (minHeight, minTime)
    }

    /// BIP68 - Untested. Called by  `checkSequenceLocksAtTip()` and `sequenceLocks()`.
    private func evaluateSequenceLocks(_ block: BlockRef, previous: BlockRef, lockPair: LockPair) async throws(Error) {
        let blockTimeDate = await medianTimePast(for: previous)
        let blockTime = Int(blockTimeDate.timeIntervalSince1970)
        if lockPair.height >= block.height || lockPair.time >= blockTime {
            logger.error("Non final transaction at block height \(block.height) (future lock time). BIP68 non-final transaction")
            throw .futureLockTime
        }
    }

    private func blockProofEquivalentTime(to: BlockRef, from: BlockRef, tip: BlockRef) -> Int {
        var r: DifficultyTarget
        let sign: Int
        if to.chainwork > from.chainwork {
            r = to.chainwork - from.chainwork
            sign = 1
        } else {
            r = from.chainwork - to.chainwork;
            sign = -1
        }
        r = r * UInt32(params.powTargetSpacing) / blockProof(tip)
        if r.bits > 63 {
            return sign * Int.max
        }
        return sign * Int(r.low64)
    }

    private func blockProof(_ block: BlockRef) -> DifficultyTarget {
        var negative = false
        var overflow = false
        let target = DifficultyTarget(compact: block.header.target, negative: &negative, overflow: &overflow)
        if negative || overflow || target.isZero {
            return DifficultyTarget(0)
        }
        // We need to compute 2**256 / (bnTarget+1), but we can't represent 2**256 as it's too large for an arith_uint256. However, as 2**256 is at least as large as bnTarget+1, it is equal to ((2**256 - bnTarget - 1) / (bnTarget+1)) + 1, or ~bnTarget / (bnTarget+1) + 1.
        return (~target / (target + 1)) + 1
    }
}

private func nowSeconds() -> TimeInterval {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .gmt
    return floor(calendar.date(bySetting: .nanosecond, value: 0, of: Date.now)!.timeIntervalSince1970)
}

private typealias LockPoints = (height: Int, time: Int, ancestor: BlockRef)
private typealias LockPair = (height: Int, time: Int)

private enum Metrics {
    static let transactionsCounter = Counter(label: "transactions")
    static let headersCounter = Counter(label: "headers")
    static let seenBlocksCounter = Counter(label: "seen-blocks")
    static let validBlocksCounter = Counter(label: "valid-blocks")
    static let validTransactionsCounter = Counter(label: "valid-transactions")
    static let blockValidationTimer = Timer(label: "block-validation", preferredDisplayUnit: .seconds)
}
