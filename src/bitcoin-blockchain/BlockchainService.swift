import Foundation
import Atomics
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

        public static let defaultMaxTries = 1_000_000
    }

    public enum Status: Sendable {
        case idle, starting, running, stopping, stopped
    }

    public enum Error: Swift.Error {
        case unsupportedBlockVersion, orphanHeader, insuficientProofOfWork, headerTooOld, headerTooNew, missingCoinbaseTransaction, coinbaseTransactionOverspends, wrongMerkleRoot, invalidTransactionInBlock, dataDirIssue

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
    public private(set) var chainTip: Block.ID! = nil

    public private(set) var mempool = [Transaction]()

    private var headers: HeadersIndex!

    private var coins: CoinsIndex!
    private var mempoolExclude = [Outpoint]()
    private var mempoolCoins = [Outpoint: UnspentOutput]()

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<Block>]()

    /// Subscriptions to new transactions.
    private var txChannels = [AsyncChannel<Transaction>]()

    /// Cache of initial block download status, uses Swift Atomics to copy the behavior of `m_cached_finished_ibd` in Bitcoin Core.
    private var finishedIDB = ManagedAtomic<Bool>(false)

    public init(params: ConsensusParams = .regtest, config: Config = .init(), logger: Logger = .init(label: "blockchain")) {
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
        let config = BlockStorageConfig(path: dataDir, magic: params.magicBytes, maxBlock: ConsensusParams.maxBlockSerializedSized)
        blockStorage = if dataDir == nil {
            TransientBlockStorage(config: config)
        } else {
            PersistentBlockStorage(config: config, logger: logger)
        }
        self.logger = logger
    }

    public func start() async { // TODO: Throw!
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
        headers = if let dataDir { PersistentHeadersIndex(path: dataDir, logger: logger) } else { TransientHeadersIndex() }
        coins = if let dataDir { PersistentCoinsIndex(path: dataDir, logger: logger) } else { TransientCoinsIndex() }

        do {
            try await blockStorage.start()
        } catch {
            logger.error("Could not start block storage.")
            fatalError("Could not start block storage.")
        }

        if await blockIndex.height == -1 {
            let genesisBlock = Block.genesis(params)
            let locator = try! await blockStorage.store(genesisBlock) // TODO: Throw
            try! await blockIndex.add(genesisBlock, locator: locator, status: .header)
            chainTip = genesisBlock.id
        } else {
            chainTip = await blockIndex.lastHeaderID // TODO: Replace with findTip()!!
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
            return try! await blockStorage.retrieve(locator)!
        }
    }

    // TODO: Cache this.
    public var synchronized: Bool {
        get async {
            let height = await blockIndex.height
            return await validatedHeight == height
        }
    }

    public var tipTime: Date {
        get async {
            precondition(status == .running)
            return await blockIndex.get(chainTip).time
        }
    }

    public var tipDifficulty: Double {
        get async {
            precondition(status == .running)
            return await blockIndex.get(chainTip).difficulty
        }
    }

    public var medianTime: Date {
        get async {
            precondition(status == .running)
            return await getMedianTimePast()
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
            return Data(await blockIndex.get(chainTip).chainwork.data.reversed())
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
        guard height >= 0, await validatedHeight >= height else {
            return nil
        }
        return await blockIndex.get(at: height).blockID
    }

    /// Returns a block header, meaning a block without it's transactions.
    public func getHeader(_ id: Block.ID) async -> Block? {
        guard await blockIndex.has(id) else {
            return nil
        }
        let blockRef = await blockIndex.get(id)
        return if let locator = blockRef.locator {
            try? await blockStorage.retrieve(locator)?.header
        } else if let header = await headers.get(blockRef.blockID) {
            header
        } else {
            preconditionFailure("Could not find header or block.")
        }
    }

    /// Gets a fully validated block by height complete with transactions.
    public func getBlock(at height: Int) async -> Block? {
        guard height >= 0, await validatedHeight >= height else {
            return nil
        }
        let blockRef = await blockIndex.get(at: height)
        guard let locator = blockRef.locator else {
            return nil
        }
        return try? await blockStorage.retrieve(locator)
    }

    /// Gets a fully validated block by ID complete with transactions.
    public func getBlock(_ id: Block.ID) async -> Block? {
        guard await blockIndex.has(id) else {
            return nil
        }
        let blockRef = await blockIndex.get(id)
        guard let locator = blockRef.locator, await validatedHeight >= blockRef.height else {
            return nil
        }
        return try? await blockStorage.retrieve(locator)
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
        let validatedHeight = await validatedHeight
        let refNext = if ref.height < validatedHeight {
            await blockIndex.get(at: ref.height + 1)
        } else {
            BlockRef?.none
        }
        let medianTime = await getMedianTimePast(at: ref.height)
        return .init(
            next: refNext?.blockID,
            height: ref.height,
            confirmations: validatedHeight - ref.height + 1,
            difficulty: ref.difficulty,
            chainwork: ref.chainwork.data,
            medianTime: medianTime
        )
    }

    /// Adds a transaction to the mempool.
    public func addTransaction(_ tx: Transaction) async throws {
        guard !mempool.contains(tx) else { return }
        guard await checkTx(tx) else { return }
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
        for out in tx.outs.enumerated() {
            mempoolCoins[.init(tx: txid, out: out.offset)] = .init(out.element)
        }
    }

    public func subscribeToBlocks() -> AsyncChannel<Block> {
        blockChannels.append(.init())
        return blockChannels.last!
    }

    public func subscribeToTxs() -> AsyncChannel<Transaction> {
        txChannels.append(.init())
        return txChannels.last!
    }

    public func unsubscribe(_ channel: AsyncChannel<Block>) {
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
        var height = await blockIndex.height
        var step = 1
        while height >= 0 {
            let blockRef = await blockIndex.get(at: height)
            have.append(blockRef.blockID)
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
        let maxHeight = await blockIndex.height
        var heightTo = maxHeight // TODO: previously `await validatedHeight`. Double check don't need to consider all headers (including ones missing transactions or not yet validated)
        let heightFrom = hitHeight + 1
        guard heightFrom <= heightTo else { return [] }
        if heightTo - heightFrom + 1 > 200 {
            heightTo = heightFrom + 199 // The limit is 200 but we are using a closed range
        }
        var headers = [Block]()
        for height in heightFrom ... heightTo {
            let blockRef = await blockIndex.get(at: height)
            let block = if let locator = blockRef.locator {
                try! await blockStorage.retrieve(locator)!
                // TODO: handle error properly
            } else if let header = headers.first(where: { $0.id == blockRef.blockID }) {
                header
            } else {
                preconditionFailure("Could not find header or block.")
            }
            headers.append(block.header)
        }
        return headers
    }

    /// Validates the block header.
    ///
    /// This function contains similar logic to `ContextualCheckBlockHeader()` in Bitcoin Core's `validation.cpp`.
    private func checkHeader(_ header: Block) async throws(Error) {

        guard await lastBlockID == header.previous else {
            // TODO: Check for all ancestors
            throw .orphanHeader
        }

        guard await header.time >= getMedianTimePast() else {
            throw .headerTooOld
        }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        guard header.time <= calendar.date(byAdding: .hour, value: 2, to: .now)! else {
            throw .headerTooNew
        }

        let height = await height
        let previousHeader = await blockIndex.get(at: height)
        let target = await getNextWorkRequired(lastHeader: previousHeader, newBlockTime: header.time, params: params)
        guard DifficultyTarget(compact: header.target) <= DifficultyTarget(compact: target), try! DifficultyTarget(header.id) <= DifficultyTarget(compact: header.target) else {
            throw .insuficientProofOfWork
        }

        // Testnet4 and regtest only: Check timestamp against prev for difficulty-adjustment blocks to prevent timewarp attacks (see https://github.com/bitcoin/bitcoin/pull/15482).
        if params.preventBlockStorms {
            // Check timestamp for the first block of each difficulty adjustment interval, except the genesis block.
            if (height + 1) % params.difficultyAdjustmentInterval == 0 {
                guard header.time.timeIntervalSince1970 >= previousHeader.time.timeIntervalSince1970  - ConsensusParams.maxTimewarp else {
                    throw .timewarpAttack
                }
            }
        }

        // Reject blocks with outdated version
        if header.version < 2 && height >= params.heightInCoinbaseHeight ||
            (header.version < 3 && height >= params.strictDERSignatureHeight) ||
            (header.version < 4 && height >= params.cltvHeight) {
            throw .unsupportedBlockVersion
        }
    }

    public func processHeaders(_ headers: [Block]) async throws(Error) {
        for header in headers {
            guard await lastBlockID != header.id else {
                // Compact block might send us a known header again
                continue
            }
            try await checkHeader(header)

            // We can use `try!` because we already checked that the parent exists when we called `checkHeader()`.
            try! await blockIndex.add(header, locator: nil, status: .header)
            await self.headers.add(header)
        }
    }

    /// Returns the IDs of the headers missing transactions up to a maximum defined by the function argument.
    public func getNextMissingBlocks(_ numberOfBlocks: Int) async -> [Data] {
        let startHeight = await validatedHeight + 1
        let maxHeight = await height
        guard startHeight <= maxHeight else { return [] }
        let delta = maxHeight - startHeight + 1
        let resolvedNumberOfBlocks = min(numberOfBlocks, delta)
        let endHeight = startHeight + resolvedNumberOfBlocks - 1
        var hashes = [Block.ID]()
        for height in startHeight ... endHeight {
            hashes.append(await blockIndex.get(at: height).blockID)
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
            guard let block = try? await blockStorage.retrieve(locator) else {
                continue
            }
            ret.append(block)
        }
        return ret
    }

    public var validatedHeight: Int {
        get async {
            await blockIndex.get(chainTip).height
        }
    }

    public var height: Int {
        get async { await blockIndex.height }
    }

    ///Last known block ID which includes headers.
    public var lastBlockID: Block.ID {
        get async {
            if await headers.isEmpty { chainTip } else { await headers.last!.id }
        }
    }

    public var headerIDs: [Block.ID] {
        get async {
            var ids = [Block.ID]()
            let height = await height
            for height in 0 ... height {
                ids.append(await blockIndex.get(at: height).blockID)
            }
            return ids
        }
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``check()``
    private func checkTransactionInputs(_ tx: Transaction, exclude: [Outpoint], auxCoins: [Outpoint : UnspentOutput]) async throws(Transaction.ValidationError) {
        precondition(!tx.isCoinbase)

        let valueIn: Amount
        let nextHeight = await validatedHeight + 1

        var valueInAcc = Amount(0)
        for input in tx.ins.enumerated() {
            let outpoint = input.element.outpoint

            // are the actual inputs available?
            guard let coin = await coins.get(outpoint) ?? auxCoins[outpoint], !exclude.contains(outpoint) else {
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

    private func calculateFees(_ tx: Transaction, exclude: [Outpoint], auxCoins: [Outpoint : UnspentOutput]) async -> Amount {
        precondition(!tx.isCoinbase)
        var valueIn = Amount(0)
        for input in tx.ins {
            let outpoint = input.outpoint

            guard let coin = await coins.get(outpoint) ?? auxCoins[outpoint] else {
                preconditionFailure()
            }
            valueIn += coin.out.value
        }
        return valueIn - tx.valueOut
    }

    private func checkTx(_ tx: Transaction, exclude: [Outpoint]? = nil, auxCoins: [Outpoint : UnspentOutput]? = nil) async -> Bool {
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
            return false
        }

        let validatedHeight = await validatedHeight

        // TODO: Enforce BIP113 (Median Time Past) for block validation only (not mempool acceptance)
        // let enforceLocktimeMedianTimePast = deploymentActiveAfter(blocks[tip], chainman, Consensus.deploymentCSV)
        // let lockTimeCutoff = enforceLocktimeMedianTimePast ? Int(getMedianTimePast(for: tip).timeIntervalSince1970)) : blockCandidate.time

        // Check that all transactions are finalized
        guard await tx.isFinal(blockHeight: validatedHeight + 1, blockTime: Int(getMedianTimePast().timeIntervalSince1970)) else {
            // TODO: `throw BlockValidationError.nonFinalTransaction` or the like.
            return false
        }

        if !tx.isCoinbase {
            var prevouts = [TransactionOutput]()
            for input in tx.ins {
                guard let coin = await coins.get(input.outpoint) ?? auxCoins[input.outpoint] else {
                    preconditionFailure() // Already checked in checkTransactionInputs
                }
                prevouts.append(coin.out)
            }
            if !tx.verifyScript(prevouts: prevouts) {
                return false // error, failed to verify tx
            }
        }
        return true
    }

    private func connectBlock(_ block: Block) async {
        // Add block
        let locator = try! await blockStorage.store(block) // TODO: throw
        let blockRef: BlockRef
        if let firstHeader = await headers.first, block.id == firstHeader.id {
            blockRef = await blockIndex.get(block.id)
            await blockIndex.update(block.id, locator: locator, status: .full)
            await headers.removeFirst()
        } else {
            /// We can use `try!` because the header has already been verified to have an existing parent in our chain.
            blockRef = try! await blockIndex.add(block, locator: locator, status: .full)
        }
        chainTip = block.id
        logger.info("New tip \(block.idHex)")

        // Remove available coins
        for tx in block.txs {
            // Remove coins
            for input in tx.ins {
                try! await coins.remove(input.outpoint)
            }
            // Add coins
            for out in tx.outs.enumerated() {
                await coins.add(.init(out.element, height: blockRef.height, isCoinbase: tx.isCoinbase), for: .init(tx: tx.id, out: out.offset))
            }
        }

        let blockCopy = block
        // Notify other nodes of new tip
        Task {
            await withDiscardingTaskGroup {
                for channel in blockChannels {
                    $0.addTask {
                        await channel.send(blockCopy)
                    }
                }
            }
        }
    }

    public func processBlock(_ block: Block) async throws(Error) {

        let chainTipRef = await blockIndex.get(chainTip)
        let nextTipHeight = chainTipRef.height + 1

        let synchronized = await synchronized
        if !synchronized {
            let fistNonBlockHeader = await blockIndex.get(at: nextTipHeight)
            if block.id != fistNonBlockHeader.blockID {
                // New block does not match pre-existing header for block:
                // Replace block entirely and mark all subsequent blocks as stale
                let removed = await blockIndex.removeAll(from: nextTipHeight)
                for r in removed {
                    if let locator = r.locator {
                        await blockStorage.remove(locator) // Will only remove from cache, not storage
                    }
                }
            }
        }

        if synchronized  {
            // We need to check the header fields
            try await checkHeader(block)
        }

        // Verify merkle root
        let expectedMerkleRoot = calculateMerkleRoot(block.txs)
        guard block.merkleRoot == expectedMerkleRoot else {
            throw .wrongMerkleRoot
        }

        var tmpExclude = [Outpoint]()
        var tmpCoins = [Outpoint: UnspentOutput]()
        guard let coinbaseTx = block.txs.first, coinbaseTx.isCoinbase else {
            throw .missingCoinbaseTransaction
        }
        var fees = Amount(0)
        for tx in block.txs {
            guard await checkTx(tx, exclude: tmpExclude, auxCoins: tmpCoins) else {
                throw .invalidTransactionInBlock
            }
            if !tx.isCoinbase {
                fees += await calculateFees(tx, exclude: tmpExclude, auxCoins: tmpCoins)
            }
            // Remove coins
            tmpExclude += tx.ins.map(\.outpoint)
            // Add coins
            let txid = tx.id
            for out in tx.outs.enumerated() {
                tmpCoins[.init(tx: txid, out: out.offset)] = .init(out.element, height: nextTipHeight, isCoinbase: tx.isCoinbase)
            }
        }

        // Check coinbase
        let nextHeight = await validatedHeight + 1
        let blockReward = getBlockSubsidy(nextHeight) + fees
        // We allow for a portion of the block reward to be left unclaimed.
        guard blockReward >= coinbaseTx.valueOut else {
            throw .coinbaseTransactionOverspends
        }

        let unclaimed = blockReward - coinbaseTx.valueOut
        precondition(unclaimed >= 0 && unclaimed <= Transaction.maxMoney) // coinbase "fee" our of range, can this ever happen??

        await connectBlock(block) // Will update chain tip and coins

        // Clean up mempool and mempoolCoins
        var newMempool = [Transaction]()
        var mpExclude = [Outpoint]()
        var mpCoins = [Outpoint: UnspentOutput]()
        for tx in mempool {
            guard await checkTx(tx, exclude: mpExclude, auxCoins: mpCoins) else {
                continue // Exclude this transaction from the new mempool
            }
            newMempool.append(tx)

            // Remove coins
            mpExclude += tx.ins.map(\.outpoint)
            // Add coins
            let txid = tx.id
            for out in tx.outs.enumerated() {
                mpCoins[.init(tx: txid, out: out.offset)] = .init(out.element)
            }
        }
        mempool = newMempool
        mempoolExclude = mpExclude
        mempoolCoins = mpCoins
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

        guard await synchronized else {
            // Waiting for pending block transactions for known headers
            preconditionFailure("Chain cannot contain unvalidated blocks.")
        }
        let chainTipRef = await blockIndex.get(chainTip)
        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)

        let mempoolTxs = mempool

        // Calculate fees
        var totalFees = Amount(0)
        for tx in mempoolTxs {
            totalFees += await calculateFees(tx, exclude: [], auxCoins: mempoolCoins) // TODO: Double-check `exclude` needs to be empty as well as the auxCoins parameter.
        }

        let blockReward = params.blockSubsidy + totalFees
        let coinbaseTx = Transaction.coinbase(version: txVersion, blockHeight: chainTipRef.height + 1, out: .init(value: blockReward, script: script), witnessMerkleRoot: witnessMerkleRoot, tag: tag)

        let previousBlockHash = chainTip!
        let txs = [coinbaseTx] + mempoolTxs
        let merkleRoot = calculateMerkleRoot(txs)

        let target = await getNextWorkRequired(lastHeader: chainTipRef, newBlockTime: blockTime, params: params)

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

        await connectBlock(block)
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
            guard let block = try? await blockStorage.retrieve(locator) else {
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
        await getTransactions([id]).first
    }

    /// Finds transactions in mempool and blocks which match any of the provided IDs.
    public func getTransactions(_ ids: [Transaction.ID]) async -> [Transaction] {
        var ret = [Transaction]()
        for tx in mempool {
            if ids.contains(tx.id) {
                ret.append(tx)
            }
        }
        for locator in await blockIndex.locators {
            guard let block = try? await blockStorage.retrieve(locator) else {
                continue
            }
            for tx in block.txs {
                if ids.contains(tx.id) {
                    ret.append(tx)
                }
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
                if Int(newBlockTime.timeIntervalSince1970) > Int(lastHeader.time.timeIntervalSince1970) + params.powTargetSpacing * 2 {
                    return proofOfWorkLimit
                } else {
                    // Return the last non-special-min-difficulty-rules-block
                    var height = heightLast
                    var header = lastHeader
                    while height > 0 && height % params.difficultyAdjustmentInterval != 0 && header.target == proofOfWorkLimit {
                        height -= 1
                        header = await blockIndex.get(at: height)
                    }
                    return header.target
                }
            }
            return lastHeader.target
        }

        // Go back by what we want to be 14 days worth of blocks
        let heightFirst = heightLast - (params.difficultyAdjustmentInterval - 1)
        precondition(heightFirst >= 0)
        let firstHeader = await blockIndex.get(at: heightFirst) // pindexLast->GetAncestor(nHeightFirst)
        return await calculateNextWorkRequired(lastHeader: lastHeader, firstBlockTime: firstHeader.time, params: params)
    }

    private func calculateNextWorkRequired(lastHeader: BlockRef, firstBlockTime: Date, params: ConsensusParams) async -> Int {
        if params.powNoRetargeting {
            return lastHeader.target
        }

        // Limit adjustment step
        var actualTimespan = Int(lastHeader.time.timeIntervalSince1970) - Int(firstBlockTime.timeIntervalSince1970)
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
            new = DifficultyTarget(compact: first.target)
        } else {
            new = DifficultyTarget(compact: lastHeader.target)
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

    private func getMedianTimePast(at height: Int? = nil) async -> Date {
        let maxHeight = await blockIndex.get(chainTip).height
        let height = height ?? maxHeight
        precondition(height >= 0 && height <= maxHeight)
        let startHeight = max(height - 11, 0)
        let blockRefs = await blockIndex.get(from: startHeight, to: height)
        let median = blockRefs.map(\.time).sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }

    private func guessVerificationProgress(for height: Int? = nil) async -> Double {
        let maxHeight = await blockIndex.get(chainTip).height
        let height = height ?? maxHeight
        precondition(height >= 0 && height <= maxHeight)

        let blockRef = await blockIndex.get(at: height)

        let now = nowSeconds()
        let blockTime = floor(blockRef.time.timeIntervalSince1970) // TODO: floor may be redundant as block always resets seconds (or at least it should)

        let chainData = params.chainData
        let chainDataTime = floor(blockRef.time.timeIntervalSince1970)

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
        if await blockStorage.status == .starting { return true }

        // This is for the active chain only.
        if chainTip == nil { return true }

        let blockRef = await blockIndex.get(chainTip)

        if try! DifficultyTarget(params.minChainwork.reversed()) > blockRef.chainwork { return true }

        let maxTipAge = TimeInterval(24 * 60 * 60) // 24 hours
        let maxTipTime = Date(timeIntervalSince1970: nowSeconds() - maxTipAge)
        if (blockRef.time < maxTipTime ) { return true }

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
        let nextBlockHeight = await blockIndex.get(chainTip).height + 1
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
