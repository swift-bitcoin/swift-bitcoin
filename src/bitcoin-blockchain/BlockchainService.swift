import Foundation
import Atomics
import Collections
import AsyncAlgorithms
import Logging
import _NIOFileSystem
import BitcoinCrypto
import BitcoinBase

public actor BlockchainService: Sendable {

    public struct Config: Sendable {

        public enum DataLocation: Sendable {
            case inMemory, defaultPath, custom(path: String)
        }

        public init(dataLocation: Config.DataLocation = .inMemory) {
            self.dataLocation = dataLocation
        }

        let dataLocation: DataLocation

        /// Maximum number of attempts to hit the difficulty target when generating blocks.
        public static let defaultMaxTries = 1_000_000
    }

    public enum Status: Sendable {
        case idle, starting, running, stopping, stopped
    }

    public enum Error: Swift.Error {
        case invalidTransactionInBlock(TransactionValidationError)
        case unsupportedBlockVersion, orphanHeader, insuficientProofOfWork, headerTooOld, headerTooNew, missingCoinbaseTransaction, coinbaseTransactionOverspends, wrongMerkleRoot, blockAlreadyExists

        case dataDirIssue, blockFileIssue, receivedCancellation

        /// Block's timestamp is too early on diff adjustment block.
        case timewarpAttack
    }

    public let params: ConsensusParams
    public let config: Config
    public let logger: Logger
    public var status = Status.idle

    private let dataDir: FilePath?

    private var blockStorage: BlockStorage!
    private var blockIndex: BlockIndex!

    public var chainTip: Block.ID! {
        bestBlock?.header.id
    }

    private(set) var bestBlock: BlockRef! = nil
    private(set) var bestHeader: BlockRef! = nil

    public private(set) var mempool = [Transaction]()

    private var coins: CoinsIndex!
    private var mempoolExclude = [Outpoint]()
    private var mempoolCoins = [Outpoint: UnspentOutput]()

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<BlockUpdate>]()

    /// Subscriptions to new transactions.
    private var txChannels = [AsyncChannel<Transaction>]()

    /// Cache of initial block download status, uses Swift Atomics to copy the behavior of `m_cached_finished_ibd` in Bitcoin Core.
    private var finishedIDB = ManagedAtomic<Bool>(false)

    private var currentlyValidating: Block.ID?

    public init(params: ConsensusParams = .regtest, config: Config = .init(), logger: Logger = .init(label: "blockchain")) {
        // TODO: Consider making this init `async throws` and maybe get rid of the life cycle (aka `start()`)
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
    }

    public func start() async { // TODO: This needs to throw. Also consider moving logic back to init.
        status = .starting
        defer { status = .running }

        let fm = FileManager.default // TODO: Switch for NIOFileSystem
        if let dataDir {
            do {
                try fm.createDirectory(atPath: dataDir.string, withIntermediateDirectories: true)
            } catch {
                logger.error("There was an issue accessing/creating the specified data directory.")
                fatalError("Could not create data directory.") // Throw .dataDirIssue
            }
        }

        blockIndex = if let dataDir { PersistentBlockIndex(path: dataDir, logger: logger) } else { TransientBlockIndex() }
        coins = if let dataDir { PersistentCoinsIndex(path: dataDir, logger: logger) } else { TransientCoinsIndex() }

        let config = BlockStorageConfig(path: dataDir, magic: params.magicBytes, maxBlock: ConsensusParams.maxBlockSerializedSized)
        do {
            blockStorage = if dataDir == nil {
                try await TransientBlockStorage(config: config, logger: logger)
            } else {
                try await PersistentBlockStorage(config: config, logger: logger)
            }
        } catch {
            logger.error("Could not start block storage.")
            fatalError("Could not start block storage.")
        }

        logger.debug("Indexes and storage initialized.")
        logger.debug("Finding best header and block…")
        bestHeader = await blockIndex.bestHeader
        if bestHeader == nil {
            logger.debug("No good header, seeding genesis block")
            let genesisBlock = Block.genesis(params)
            let locator = try! await blockStorage.store(genesisBlock, undo: BlockUndo(spentCoins: [])) // TODO: Throw
            bestBlock = try! await blockIndex.add(genesisBlock, locator: locator, status: .full)
            bestHeader = bestBlock
        } else {
            logger.debug("Found best header, now finding best block block…")
            bestBlock = await blockIndex.bestAncestor(of: bestHeader)
        }
        logger.debug("Found best block.")

        // Connect the next block if transactions are already downloaded and check against merkle root
        guard bestHeader.height > bestBlock.height else {
            return
        }
        let nextRef = await blockIndex.get(at: bestBlock.height + 1)
        guard nextRef.status == .merkle else {
            return
        }
        logger.debug("Will connect next block \(nextRef.header.idHex)")
        Task {
            try await connectBlock(ref: nextRef)
        }
    }

    public func stop() async {
        status = .stopping
        defer { status = .stopped }
        for blockChannel in blockChannels {
            unsubscribe(blockChannel)
        }
        for txChannel in txChannels {
            unsubscribe(txChannel)
        }
    }

    public var genesisBlock: Block {
        get async {
            let locator = await blockIndex.get(at: 0).locator!
            let (block, _) = try! await blockStorage.retrieve(locator)
            return block
        }
    }

    public var synchronized: Bool {
        bestHeader.status == .full
    }

    public var tipTime: Date {
        bestBlock.header.time
    }

    public var tipDifficulty: Double {
        bestBlock.difficulty
    }

    public var medianTime: Date {
        get async {
            precondition(status == .running)
            return await getMedianTimePast(for: bestBlock)
        }
    }

    public var verificationProgress: Double {
        get async {
            precondition(status == .running)
            return await guessVerificationProgress()
        }
    }

    public var initialBlockDownload: Bool {
        get async {
            precondition(status == .running)
            return await isInitialBlockDownload()
        }
    }

    public var chainwork: Data {
        get async {
            precondition(status == .running)
            return Data(bestBlock.chainwork.data.reversed())
        }
    }

    public var sizeOnDisk: Int {
        get async {
            precondition(status == .running)
            return await blockStorage.sizeOnDisk
        }
    }

    /// Gets a fully validated block by height complete with transactions.
    public func getBlockID(at height: Int) async -> Block.ID? {
        guard height >= 0, bestBlock.height >= height else {
            return nil
        }
        return await blockIndex.get(at: height).header.id
    }

    /// Returns a block header, meaning a block without it's transactions.
    public func getHeader(_ id: Block.ID) async -> Block? {
        guard await blockIndex.has(id) else {
            return nil
        }
        let blockRef = await blockIndex.get(id)
        return blockRef.header
    }

    /// Gets a fully validated block by height complete with transactions.
    public func getBlock(at height: Int) async -> Block? {
        guard height >= 0, bestBlock.height >= height else {
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
    public func getBlock(_ id: Block.ID) async -> Block? {
        guard await blockIndex.has(id) else {
            return nil
        }
        let blockRef = await blockIndex.get(id)
        guard let locator = blockRef.locator, bestBlock.height >= blockRef.height else {
            return nil
        }
        return if let (block, _) = try? await blockStorage.retrieve(locator) {
            block
        } else { nil }
    }

    /// Gets a fully validated block by ID complete with transactions.
    public func getBlockHeight(_ id: Block.ID) async -> Int? {
        guard await blockIndex.has(id) else {
            return nil
        }
        let blockRef = await blockIndex.get(id)
        return blockRef.height
    }

    public func getBlockInfo(_ id: Block.ID) async -> BlockInfo? {
        guard await blockIndex.has(id) else {
            return nil
        }
        let ref = await blockIndex.get(id)
        let refNext = if ref.height < bestBlock.height {
            await blockIndex.get(at: ref.height + 1)
        } else {
            BlockRef?.none
        }
        let medianTime = await getMedianTimePast(for: ref)
        return .init(
            next: refNext?.header.id,
            height: ref.height,
            confirmations: bestBlock.height - ref.height + 1,
            difficulty: ref.difficulty,
            chainwork: ref.chainwork.data,
            medianTime: medianTime
        )
    }

    /// Adds a transaction to the mempool.
    ///
    /// Returns silently if transaction is already in the mempool.
    public func addTransaction(_ tx: Transaction) async throws(TransactionValidationError) {
        guard !mempool.contains(tx) else {
            logger.warning("Transaction already in mempool")
            return
        }
        do {
            try await checkTx(tx, checkStandardness: true, blockRef: bestBlock)
        } catch {
            logger.error("Failed transaction check\n\n\(error)")
            throw error
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

    public func subscribeToBlocks() -> AsyncChannel<BlockUpdate> {
        blockChannels.append(.init())
        return blockChannels.last!
    }

    public func subscribeToTxs() -> AsyncChannel<Transaction> {
        txChannels.append(.init())
        return txChannels.last!
    }

    public func unsubscribe(_ channel: AsyncChannel<BlockUpdate>) {
        channel.finish()
        blockChannels.removeAll(where: { $0 === channel })
    }

    public func unsubscribe(_ channel: AsyncChannel<Transaction>) {
        channel.finish()
        txChannels.removeAll(where: { $0 === channel })
    }

    /// To create the block locator hashes, keep pushing hashes until you go back to the genesis block. After pushing 10 hashes back, the step backwards doubles every loop.
    public func makeBlockLocator() async -> [Data] {
        precondition(status == .running)

        var have = [Data]()
        var height = bestHeader.height // TODO: This does not ignore stale/invalidated blocks
        var step = 1
        while height >= 0 {
            let blockRef = await blockIndex.get(at: height)
            have.append(blockRef.header.id)
            if height == 0 { break }

            // Exponentially larger steps back, plus the genesis block.
            if have.count >= 10 { step *= 2 }
            height = max(height - step, 0) // TODO: Use "skiplist"
        }
        return have
    }

    public func findHeaders(using locator: [Data]) async -> [Block] {
        var hitHeight = Int?.none
        for blockID in locator {
            if await blockIndex.has(blockID) {
                hitHeight = await blockIndex.get(blockID).height
                break
            }
        }
        guard let hitHeight else { return [] }
        let maxHeight = bestBlock.height
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

    /// Validates the block header.
    ///
    /// This function contains similar logic to `ContextualCheckBlockHeader()` in Bitcoin Core's `validation.cpp`.
    public func processHeader(_ header: Block) async throws(Error) {
        precondition(header.txs.isEmpty)

        guard bestHeader.header.id == header.previous else {
            // TODO: Check for all ancestors in case its a reorg
            logger.error("Header \(header.idHex) - previous header not found \(header.previous.reversed().hex)")
            throw .orphanHeader
        }

        guard await header.time >= getMedianTimePast(for: bestBlock) else {
            logger.error("Header \(header.idHex) - timestamp too old \(header.time)")
            throw .headerTooOld
        }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        guard header.time <= calendar.date(byAdding: .hour, value: 2, to: .now)! else {
            logger.error("Header \(header.idHex) - timestamp too new \(header.time)")
            throw .headerTooNew
        }

        let previousHeader = await blockIndex.get(at: height)
        let target = await getNextWorkRequired(lastHeader: previousHeader, newBlockTime: header.time, params: params)
        guard DifficultyTarget(compact: header.target) <= DifficultyTarget(compact: target), try! DifficultyTarget(header.id) <= DifficultyTarget(compact: header.target) else {
            logger.error("Header \(header.idHex) - insufficient proof of work \(header.target)")
            throw .insuficientProofOfWork
        }

        // Testnet4 and regtest only: Check timestamp against prev for difficulty-adjustment blocks to prevent timewarp attacks (see https://github.com/bitcoin/bitcoin/pull/15482).
        if params.preventBlockStorms {
            // Check timestamp for the first block of each difficulty adjustment interval, except the genesis block.
            if (height + 1) % params.difficultyAdjustmentInterval == 0 {
                guard header.time.timeIntervalSince1970 >= previousHeader.header.time.timeIntervalSince1970  - ConsensusParams.maxTimewarp else {
                    logger.error("Header \(header.idHex) - potential timewarp attack")
                    throw .timewarpAttack
                }
            }
        }

        // Reject blocks with outdated version
        if header.version < 2 && height >= params.heightInCoinbaseHeight ||
            (header.version < 3 && height >= params.strictDERSignatureHeight) ||
            (header.version < 4 && height >= params.cltvHeight) {
            logger.error("Header \(header.idHex) - unsupported block version \(header.version)")
            throw .unsupportedBlockVersion
        }

        // We can use `try!` because we already checked that the parent exists when we called `checkHeader()`.
        bestHeader = try! await blockIndex.add(header, locator: nil, status: .header)
    }

    public func processHeaders(_ headers: [Block]) async throws(Error) {
        for header in headers {
            guard await !blockIndex.has(header.id) else {
                // Compact block might send us a known header again
                continue
            }
            try await processHeader(header)
        }
    }

    /// Returns the IDs of the headers missing transactions up to a maximum defined by the function argument.
    public func getNextMissingBlocks(_ numberOfBlocks: Int) async -> [Data] {
        guard !synchronized else {
            return []
        }
        var h = bestBlock.height + 1
        var hashes = [Block.ID]()
        while h <= height, hashes.count < numberOfBlocks {
            let ref = await blockIndex.get(at: h)
            if ref.status == .header {
                hashes.append(ref.header.id)
            }
            h += 1
        }
        return hashes
    }

    /// Returns multiple fully validated blocks matching the provided IDs.
    public func getBlocks(_ blockIDs: [Block.ID]) async -> [Block] {
        var ret = [Block]()
        for blockID in blockIDs {
            guard await blockIndex.has(blockID) else {
                continue
            }
            let blockRef = await blockIndex.get(blockID)
            guard let locator = blockRef.locator, blockRef.status == .full else {
                continue
            }
            guard let (block, _) = try? await blockStorage.retrieve(locator) else {
                continue
            }
            ret.append(block)
        }
        return ret
    }

    public var validatedHeight: Int {
        bestBlock.height
    }

    /// The height of the most recent header.
    public var height: Int {
        bestHeader.height
    }

    ///Last known block ID which includes headers.
    public var lastBlockID: Block.ID {
        bestHeader.header.id
    }

    public var headerIDs: [Block.ID] {
        get async {
            var ids = [Block.ID]()
            for height in 0 ... height { // TODO: Account for stale/invalids?
                ids.append(await blockIndex.get(at: height).header.id)
            }
            return ids
        }
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``check()``
    private func checkTransactionInputs(_ tx: Transaction, exclude: [Outpoint], auxCoins: [Outpoint : UnspentOutput]) async throws(Transaction.ValidationError) {
        precondition(!tx.isCoinbase)

        let valueIn: Amount
        let nextHeight = bestBlock.height + 1

        var valueInAcc = Amount(0)
        for input in tx.ins {
            let outpoint = input.outpoint

            // are the actual inputs available?
            guard let coin = try! await coins.get(outpoint) ?? auxCoins[outpoint], !exclude.contains(outpoint) else {
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

            guard let coin = try! await coins.get(outpoint) ?? auxCoins[outpoint] else {
                preconditionFailure()
            }
            valueIn += coin.out.value
        }
        return valueIn - tx.valueOut
    }

    private func checkTx(_ tx: Transaction, checkStandardness: Bool = false, blockRef: BlockRef, assumeValidHeight: Int? = nil, exclude: [Outpoint]? = nil, auxCoins: [Outpoint : UnspentOutput]? = nil) async throws(TransactionValidationError) {
        let exclude = exclude ?? mempoolExclude
        let auxCoins = auxCoins ?? mempoolCoins

        // Check tx
        do {
            try tx.check(weightLimit: ConsensusParams.maxBlockWeight)
            if !tx.isCoinbase {
                try await checkTransactionInputs(tx, exclude: exclude, auxCoins: auxCoins)
            }

            // TODO: `checkSequenceLocks(tx, verifyLockTimeSequence: Bool, coins: [Outpoint : UnspentOutput], previousBlockMedianTimePast: Int)`
        } catch {
            logger.error("Failed transaction check:\n\n\(error)")
            throw .transactionCheckError(error)
        }

        let blockHeight = blockRef.height + 1

        // TODO: Enforce BIP113 (Median Time Past) for block validation only (not mempool acceptance)
        // let enforceLocktimeMedianTimePast = deploymentActiveAfter(blocks[tip], chainman, Consensus.deploymentCSV)
        // let enforceLocktimeMedianTimePast = blockHeight >= params.csvHeight ???
        // let lockTimeCutoff = enforceLocktimeMedianTimePast ? Int(getMedianTimePast(for: tip).timeIntervalSince1970)) : blockCandidate.time

        // Check that all transactions are finalized
        guard await tx.isFinal(blockHeight: blockHeight, blockTime: Int(getMedianTimePast(for: blockRef).timeIntervalSince1970)) else {
            logger.error("Transaction not final")
            throw .nonFinalTransaction
        }

        if !tx.isCoinbase {
            var prevouts = [TransactionOutput]()
            for input in tx.ins {
                guard let coin = try! await coins.get(input.outpoint) ?? auxCoins[input.outpoint] else {
                    preconditionFailure() // Already checked in checkTransactionInputs
                }
                prevouts.append(coin.out)
            }
            if let assumeValidHeight, blockHeight <= assumeValidHeight {
                // TODO: Check minimum chainwork #396
                logger.info("Skipping script validation due to assume valid configuration")
                return
            }
            if !tx.verifyScript(prevouts: prevouts, config: checkStandardness ? .standard : .mandatory) {
                logger.error("Failed script validation")
                throw .scriptError
            }
        }
    }

    public func processBlock(_ block: Block, immediate: Bool = true) async throws(Error) {
        let blockRef = try await checkBlock(block)
        guard blockRef.previous == Block.nullParent || blockRef.previous == bestBlock.header.id else {
            logger.debug("Holding validation of block \(block.idHex)")
            return
        }
        if immediate {
            try await connectBlock(block: block)
            return
        }
        logger.debug("Initiating validation of block \(block.idHex)")
        Task {
            try await connectBlock(block: block)
        }
    }

    /// Processes a block complete with transactions.
    ///
    /// If it is the first time we see this block, its header will be processed first.
    /// If the block builds on the acvite chain tip, it will be connected thus validating its transactions.
    /// Otherwise the index will be updated to reflect that the merkle root has been verified.
    private func checkBlock(_ block: Block) async throws(Error) -> BlockRef {
        logger.debug("Processing block \(block.idHex)")

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

        if await !blockIndex.has(block.id) {
            logger.debug("Unknown block \(block.idHex), processing header")
            try await processHeader(block.header)
        }

        logger.debug("Processing block txs \(block.idHex)")

        let blockRef = await blockIndex.get(block.id)
        guard blockRef.status == .header else {
            logger.warning("Block \(block.idHex) already exist with status \(blockRef.status)")
            throw .blockAlreadyExists
        }

        logger.debug("Block \(block.idHex) merkle status validated")
        let updatedRef: BlockRef
        do {
            let locator = try await blockStorage.store(block)
            updatedRef = await blockIndex.update(block.id, locator: locator, status: .merkle)
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

    /// If we have a header in our index it updates it's validation. If not it adds the block to the index. Adds the block to storage along with undo information and updates coins (chainstate).
    private func connectBlock(block cachedBlock: Block? = nil, ref blockRef: BlockRef? = nil) async throws(Error) {

        // This function is called recursively so we check for Task cancelation at every incarnation
        guard !Task.isCancelled else { throw .receivedCancellation }

        precondition(cachedBlock != nil || blockRef != nil)
        let blockID = cachedBlock?.id ?? blockRef!.header.id

        if currentlyValidating == blockID {
            return
        }
        currentlyValidating = blockID

        let blockRef = if let blockRef {
            blockRef
        } else {
            await blockIndex.get(blockID)
        }
        precondition(blockRef.header.id == blockID && blockRef.status == .merkle)
        guard let blockOnlyLocator = blockRef.locator else {
            preconditionFailure()
        }
        precondition(blockOnlyLocator.undoOffset == -1)
        let block: Block
        if let cachedBlock {
            block = cachedBlock
        } else {
            do {
                 (block, _) = try await blockStorage.retrieve(blockOnlyLocator)
            } catch {
                throw .blockFileIssue
            }
        }

        // #396
        // TODO: Min chain work
        logger.debug("Connecting block \(block.idHex)")

        let assumeValidHeight: Int? = if let assumeValid = params.assumeValid {
            await blockIndex.get(assumeValid).height
        } else {
            nil
        }

        var fees = Amount(0)
        var tmpExclude = [Outpoint]()
        var tmpCoins = [Outpoint: UnspentOutput]()
        for txIndex in block.txs.indices {
            guard !Task.isCancelled else {
                throw .receivedCancellation
            }
            let tx = block.txs[txIndex]
            do {
                try await checkTx(tx, blockRef: bestBlock, assumeValidHeight: assumeValidHeight, exclude: tmpExclude, auxCoins: tmpCoins)
            } catch {

                // TODO: Invalidate all descendants (blocks that build upon this block)
                logger.error("Invalid transaction #\(txIndex) in block \(block.idHex)\n\n\(error)")
                throw .invalidTransactionInBlock(error)
            }
            if !tx.isCoinbase {
                fees += await calculateFees(tx, auxCoins: tmpCoins)
            }
            // Remove coins
            tmpExclude += tx.ins.map(\.outpoint)
            // Add coins
            let txid = tx.id
            for (i, out) in tx.outs.enumerated() {
                tmpCoins[.init(tx: txid, out: i)] = .init(out, height: blockRef.height, isCoinbase: tx.isCoinbase)
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
        let previousRef: BlockRef?
        if block.previous == Block.nullParent {
            previousRef = nil
        } else if await blockIndex.has(block.previous) {
            previousRef = await blockIndex.get(block.previous)
        } else {
            logger.error("Could not connect block because parent is missing from index.")
            return
        }

        let newBlockHeight = if let previousRef { previousRef.height + 1} else { 0 }

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
        let spentCoins = try! await coins.update(remove: outpointsToRemove, add: newCoins)
        let blockUndo = BlockUndo(spentCoins: spentCoins)

        // Clean up mempool and mempoolCoins
        var newMempool = [Transaction]()
        var mpExclude = [Outpoint]()
        var mpCoins = [Outpoint: UnspentOutput]()
        for tx in mempool {
            do {
                try await checkTx(tx, blockRef: blockRef, assumeValidHeight: assumeValidHeight, exclude: mpExclude, auxCoins: mpCoins)
            } catch {
                logger.warning("Mempool transaction became invalid")
                continue // Exclude this transaction from the new mempool
            }

            newMempool.append(tx)

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
        bestBlock = await blockIndex.update(block.id, locator: newLocator, status: .full)
        if bestHeader.header.id == bestBlock.header.id {
            bestHeader = bestBlock
        }

        logger.info("New tip: \(block.idHex)")
        // Notify other nodes of new tip
        Task { [ status = bestBlock.status, height = bestBlock.height] in
            await withDiscardingTaskGroup {
                for channel in blockChannels {
                    $0.addTask {
                        await channel.send((block, status, height))
                    }
                }
            }
        }

        // Connect the next block if transactions are already downloaded and check against merkle root
        guard bestHeader.height > bestBlock.height else {
            currentlyValidating = nil
            return
        }
        let nextRef = await blockIndex.get(at: blockRef.height + 1)
        guard nextRef.status == .merkle else {
            currentlyValidating = nil
            return
        }
        logger.debug("Will connect next block \(nextRef.header.idHex)")
        try await connectBlock(ref: nextRef)
    }

    public func undoLastBlock() async throws  {
        guard synchronized else {
            return
        }
        guard let locator = bestBlock.locator else {
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
        try await coins.update(remove: outpointsToRemove, add: newCoins)
        bestBlock = await blockIndex.undoLastBlock()
        bestHeader = bestBlock
    }

    @discardableResult public func generateToScript(_ script: Script, blocks: Int = 1, maxTries: Int = Config.defaultMaxTries, blockTime: Date? = nil) async -> [Block.ID] {
        var ids = [Block.ID]()
        for _ in 0 ..< blocks {
            if let block = await generateTo(script, maxTries: maxTries, blockTime: blockTime ?? .now) {
                ids.append(block.id)
            }
        }
        return ids
    }

    @discardableResult public func generateTo(_ pubkey: PublicKey, blockTime: Date = .now) async -> Block? {
        logger.info("Generating blocks with coinbase reward going to public key.")
        return await generateTo(Script.payToPubkeyHash(pubkey), blockTime: blockTime)
    }

    /// Generates a block using the mempool transactions and locks the coinbase reward output to the provided public key hash.
    ///
    /// This function essentially mines a block in current thread so it has the potential to completely block. Future versions of this method will provide asynchronous control via detached background task.
    @discardableResult public func generateTo(_ script: Script, initialNonce: Int = 0, maxTries: Int = Config.defaultMaxTries, blockTime: Date = .now, tag: String? = nil, txVersion: Transaction.Version? = nil) async -> Block? {
        logger.info("Generating blocks with coinbase reward going to public key hash.")

        guard synchronized else {
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
        let coinbaseTx = Transaction.coinbase(version: txVersion, blockHeight: bestBlock.height + 1, out: .init(value: blockReward, script: script), witnessMerkleRoot: witnessMerkleRoot, tag: tag)

        let previousBlockHash = bestBlock.header.id
        let txs = [coinbaseTx] + mempoolTxs
        let merkleRoot = calculateMerkleRoot(txs)

        let target = await getNextWorkRequired(lastHeader: bestBlock, newBlockTime: blockTime, params: params)

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

        // Reset mempool
        mempool = []
        mempoolExclude = []
        mempoolCoins = [:]

        let blockRef = try! await checkBlock(block)
        try! await connectBlock(block: block, ref: blockRef)
        return block
    }

    public func calculateMissingTxs(ids: [Transaction.ID]) async -> [Transaction.ID] {
        var newIDs = ids
        for tx in mempool {
            if ids.contains(tx.id) {
                newIDs.removeAll { $0 == tx.id }
            }
        }
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
        return newIDs
    }

    public func calculateMissingBlocks(ids: [Block.ID]) async -> [Block.ID] {
        await blockIndex.calculateMissingBlocks(ids)
    }

    /// Gets a transaction by ID looking into mempool and blocks.
    public func getTransaction(_ id: Transaction.ID) async -> Transaction? {
        for tx in mempool {
            if id == tx.id {
                return tx
            }
        }
        for locator in await blockIndex.locators {
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
    public func getTransactions(_ ids: [Transaction.ID]) async -> [Transaction] {
        var ret = [Transaction]()
        for tx in mempool {
            if ids.contains(tx.id) {
                ret.append(tx)
            }
        }
        return ret
    }

    /// Checks mempool for missing transactions.
    public func findMempoolTxs(shortIDs: [UInt64], header: Block, nonce: UInt64) -> [Transaction?] {
        let (first, second) = header.makeShortIDParams(nonce: nonce)
        let mempoolShortIDs = mempool.map { tx in tx.makeShortTxID(nonce: nonce, first: first, second: second)}
        return shortIDs.map { id in
            guard let i = mempoolShortIDs.firstIndex(of: id) else {
                return nil
            }
            return mempool[i]
        }
    }

    public func currentUTXOSet() async -> [Outpoint : UnspentOutput] {
        await coins.all
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
        let firstHeader = await blockIndex.get(at: heightFirst) // pindexLast->GetAncestor(nHeightFirst)
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

    private func getMedianTimePast(for header: BlockRef) async -> Date {
        let blockRefs = await blockIndex.get(from: header, count: 11)
        let median = blockRefs.map(\.header.time).sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }

    /*
    private func getMedianTimePast(at height: Int? = nil) async -> Date {
        let maxHeight = bestBlock.height
        let height = height ?? maxHeight
        precondition(height >= 0 && height <= maxHeight)
        let startHeight = max(height - 11, 0)
        let blockRefs = await blockIndex.get(from: startHeight, to: height)
        let median = blockRefs.map(\.header.time).sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }
    */

    private func guessVerificationProgress(for height: Int? = nil) async -> Double {
        let maxHeight = bestBlock.height
        let height = height ?? maxHeight
        precondition(height >= 0 && height <= maxHeight)

        let blockRef = await blockIndex.get(at: height)

        let now = nowSeconds()
        let blockTime = floor(blockRef.header.time.timeIntervalSince1970) // TODO: floor may be redundant as block always resets seconds (or at least it should)

        let chainData = params.chainData
        let chainDataTime = floor(blockRef.header.time.timeIntervalSince1970)

        let txTotal: Double
        if blockRef.chainTxCount <= chainData.txCount {
            txTotal = Double(chainData.txCount) + (now - chainDataTime) * chainData.txRate
        } else {
            txTotal = Double(blockRef.chainTxCount)  + (now - blockTime) * chainData.txRate
        }
        return min(Double(blockRef.chainTxCount) / txTotal, 1.0)
    }

    private func isInitialBlockDownload() async -> Bool {
        if finishedIDB.load(ordering: .relaxed) { return false }

        // Currently this function is never called before the service has started including all blocks indexed. The process could become more async in the future so leaving this line here.
        // if await blockStorage.status == .starting { return true }

        // This is for the active chain only.
        if bestBlock == nil { return true }

        if try! DifficultyTarget(params.minChainwork.reversed()) > bestBlock.chainwork { return true }

        let maxTipAge = TimeInterval(24 * 60 * 60) // 24 hours
        let maxTipTime = Date(timeIntervalSince1970: nowSeconds() - maxTipAge)
        if (bestBlock.header.time < maxTipTime ) { return true }

        logger.info("Leaving InitialBlockDownload (latching to false)")
        finishedIDB.store(true, ordering: .relaxed)
        return false
    }

    /// BIP68 - Untested - Entrypoint 1.
    private func checkSequenceLocks(_ tx: Transaction, verifyLockTimeSequence: Bool, coins: [Outpoint : UnspentOutput], previousBlockMedianTimePast: Int) async throws {
        // CheckSequenceLocks() uses chainActive.Height()+1 to evaluate
        // height based locks because when SequenceLocks() is called within
        // ConnectBlock(), the height of the block *being*
        // evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the
        // *next* block, we need to use one more than chainActive.Height()
        let nextBlockHeight = bestBlock.height + 1
        var heights = [Int]()
        // pcoinsTip contains the UTXO set for chainActive.Tip()
        for input in tx.ins {
            guard let coin = coins[input.outpoint] else {
                preconditionFailure()
            }
            if coin.isMempool {
                // Assume all mempool transaction confirm in the next block
                heights.append(nextBlockHeight)
            } else {
                heights.append(coin.height)
            }
        }
        let lockPair = tx.calculateSequenceLocks(verifyLockTimeSequence: verifyLockTimeSequence, previousHeights: &heights, blockHeight: nextBlockHeight)
        try tx.evaluateSequenceLocks(blockHeight: nextBlockHeight, previousBlockMedianTimePast: previousBlockMedianTimePast, lockPair: lockPair)
    }
}

private func nowSeconds() -> Double {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .gmt
    return floor(calendar.date(bySetting: .nanosecond, value: 0, of: Date.now)!.timeIntervalSince1970)
}

public typealias BlockUpdate = (Block, ValidationStatus, Int /* Height */)
