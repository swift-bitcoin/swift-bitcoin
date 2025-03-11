import Foundation
import Atomics
import AsyncAlgorithms
import Logging
import _NIOFileSystem
import BitcoinCrypto
import BitcoinBase

private let logger = Logger(label: "swift-bitcoin|BlockchainService")

public actor BlockchainService: Sendable {

    public struct Config: Sendable {

        public enum DataLocation: Sendable {
            case memory, defaultDirectory, customDirectory(String)
        }

        public init(dataLocation: Config.DataLocation = .memory) {
            self.dataLocation = dataLocation
        }

        let dataLocation: DataLocation

        public static let defaultMaxTries = 1_000_000
    }

    public enum Status: Sendable {
        case idle, starting, running, stopping, stopped
    }

    public enum Error: Swift.Error {
        case unsupportedBlockVersion, orphanHeader, insuficientProofOfWork, headerTooOld, headerTooNew, missingCoinbaseTransaction, coinbaseTransactionOverspends, wrongMerkleRooot, invalidTransactionInBlock, dataDirIssue
    }

    public let params: ConsensusParams
    public let config: Config
    public var status = Status.idle

    private let dataDir: FilePath?

    private var blockStorage: BlockStorage!
    private var blockIndex: BlockIndex!
    public private(set) var chainTip: BlockID! = .none

    public private(set) var mempool = [BitcoinTx]()

    private var headers: HeadersIndex!

    private var coins: CoinsIndex!
    private var mempoolExclude = [TxOutpoint]()
    private var mempoolCoins = [TxOutpoint: UnspentOut]()

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<TxBlock>]()

    /// Subscriptions to new transactions.
    private var txChannels = [AsyncChannel<BitcoinTx>]()

    /// Cache of initial block download status, uses Swift Atomics to copy the behavior of `m_cached_finished_ibd` in Bitcoin Core.
    private var finishedIDB = ManagedAtomic<Bool>(false)

    public init(params: ConsensusParams = .regtest, config: Config = .init()) {
        self.params = params
        self.config = config
        switch config.dataLocation {
        case .defaultDirectory:
            dataDir = FilePath(URL.homeDirectory.relativePath).appending(".swift-bitcoin/data") // TODO: Centralize this logic. Make async with NIOFileSystem and move to start()?
        case .customDirectory(let customDataDir):
            let customDataDirPath = FilePath(customDataDir)
            precondition(customDataDirPath.isAbsolute)
            dataDir = customDataDirPath
        default:
            dataDir = .none
        }
        let config = BlockStorageConfig(path: dataDir, magic: params.magicBytes, maxBlock: ConsensusParams.maxBlockSerializedSized)
        blockStorage = if dataDir == .none {
            InMemoryBlockStorage(config: config)
        } else {
            DiskBlockStorage(config: config)
        }
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

        blockIndex = if let dataDir { DBBlockIndex(path: dataDir) } else { InMemoryBlockIndex() }
        headers = if let dataDir { DBHeadersIndex(path: dataDir) } else { InMemoryHeadersIndex() }
        coins = if let dataDir { DBCoinsIndex(path: dataDir) } else { InMemoryCoinsIndex() }

        do {
            try await blockStorage.start()
        } catch {
            logger.error("Could not start block storage.")
            fatalError("Could not start block storage.")
        }

        if await blockIndex.height == -1 {
            let genesisBlock = TxBlock.makeGenesisBlock(params: params)
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

    public var genesisBlock: TxBlock {
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
            return Data(await blockIndex.get(chainTip).chainwork.binaryData.reversed())
        }
    }

    public var sizeOnDisk: Int {
        get async {
            precondition(status == .running)
            return await blockStorage.sizeOnDisk
        }
    }

    /// Gets a fully validated block by height complete with transactions.
    public func getBlockID(at height: Int) async -> BlockID? {
        guard height >= 0, await validatedHeight >= height else {
            return .none
        }
        return await blockIndex.get(at: height).blockID
    }

    /// Returns a block header, meaning a block without it's transactions.
    public func getHeader(_ id: BlockID) async -> TxBlock? {
        guard await blockIndex.has(id) else {
            return .none
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
    public func getBlock(at height: Int) async -> TxBlock? {
        guard height >= 0, await validatedHeight >= height else {
            return .none
        }
        let blockRef = await blockIndex.get(at: height)
        guard let locator = blockRef.locator else {
            return .none
        }
        return try? await blockStorage.retrieve(locator)
    }

    /// Gets a fully validated block by ID complete with transactions.
    public func getBlock(_ id: BlockID) async -> TxBlock? {
        guard await blockIndex.has(id) else {
            return .none
        }
        let blockRef = await blockIndex.get(id)
        guard let locator = blockRef.locator, await validatedHeight >= blockRef.height else {
            return .none
        }
        return try? await blockStorage.retrieve(locator)
    }

    /// Gets a fully validated block by ID complete with transactions.
    public func getBlockHeight(_ id: BlockID) async -> Int? {
        guard await blockIndex.has(id) else {
            return .none
        }
        let blockRef = await blockIndex.get(id)
        return blockRef.height
    }

    public func getBlockInfo(_ id: BlockID) async -> BlockInfo? {
        guard await blockIndex.has(id) else {
            return .none
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
            chainwork: ref.chainwork.binaryData,
            medianTime: medianTime
        )
    }

    /// Adds a transaction to the mempool.
    public func addTx(_ tx: BitcoinTx) async throws {
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
            mempoolCoins[.init(tx: txid, txOut: out.offset)] = .init(out.element)
        }
    }

    public func subscribeToBlocks() -> AsyncChannel<TxBlock> {
        blockChannels.append(.init())
        return blockChannels.last!
    }

    public func subscribeToTxs() -> AsyncChannel<BitcoinTx> {
        txChannels.append(.init())
        return txChannels.last!
    }

    public func unsubscribe(_ channel: AsyncChannel<TxBlock>) {
        channel.finish()
        blockChannels.removeAll(where: { $0 === channel })
    }

    public func unsubscribe(_ channel: AsyncChannel<BitcoinTx>) {
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

    public func findHeaders(using locator: [Data]) async -> [TxBlock] {
        var hitHeight = Int?.none
        for blockID in locator {
            if await blockIndex.has(blockID) {
                hitHeight = await blockIndex.get(blockID).height
                break
            }
        }
        guard let hitHeight else { return [] }
        var heightTo = await blockIndex.height // TODO: previously `await validatedHeight`. Double check don't need to consider all headers (including ones missing transactions or not yet validated)
        let heightFrom = hitHeight + 1
        guard heightFrom <= heightTo else { return [] }
        if heightTo - heightFrom + 1 > 200 {
            heightTo = heightFrom + 199 // The limit is 200 but we are using a closed range
        }
        var headers = [TxBlock]()
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

    private func checkHeader(_ header: TxBlock) async throws(Error) {
        guard header.version == 0x20000000 else {
            throw .unsupportedBlockVersion
        }

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

        let target = await getNextWorkRequired(forHeight: await height, newBlockTime: header.time, params: params)
        guard DifficultyTarget(compact: header.target) <= DifficultyTarget(compact: target), try! DifficultyTarget(binaryData: header.hash) <= DifficultyTarget(compact: header.target) else {
            throw .insuficientProofOfWork
        }
    }

    public func processHeaders(_ headers: [TxBlock]) async throws(Error) {
        for header in headers {
            guard await lastBlockID != header.id else {
                // Compact block might send us a known header again
                continue
            }
            try await checkHeader(header)

            // We can use `try!` because we already checked that the parent exists when we called `checkHeader()`.
            try! await blockIndex.add(header, locator: .none, status: .header)
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
        var hashes = [BlockID]()
        for height in startHeight ... endHeight {
            hashes.append(await blockIndex.get(at: height).blockID)
        }
        return hashes
    }

    /// Returns multiple fully validated blocks matching the provided IDs.
    public func getBlocks(_ blockIDs: [BlockID]) async -> [TxBlock] {
        var ret = [TxBlock]()
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
        get async { await blockIndex.get(chainTip).height }
    }

    public var height: Int {
        get async { await blockIndex.height }
    }

    ///Last known block ID which includes headers.
    public var lastBlockID: BlockID {
        get async {
            if await headers.isEmpty { chainTip } else { await headers.last!.id }
        }
    }

    public var headerIDs: [BlockID] {
        get async {
            var ids = [BlockID]()
            let height = await height
            for height in 0 ... height {
                ids.append(await blockIndex.get(at: height).blockID)
            }
            return ids
        }
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``check()``
    private func checkTxIns(_ tx: BitcoinTx, exclude: [TxOutpoint], auxCoins: [TxOutpoint : UnspentOut]) async throws(TxError) {
        precondition(!tx.isCoinbase)

        let valueIn: SatoshiAmount
        let nextHeight = await validatedHeight + 1

        var valueInAcc = SatoshiAmount(0)
        for txIn in tx.ins.enumerated() {
            let outpoint = txIn.element.outpoint

            // are the actual inputs available?
            guard let coin = await coins.get(outpoint) ?? auxCoins[outpoint], !exclude.contains(outpoint) else {
                throw .inputMissingOrSpent
            }
            guard !coin.isCoinbase || nextHeight - coin.height >= params.coinbaseMaturity else {
                throw .prematureCoinbaseSpend
            }
            valueInAcc += coin.txOut.value
            guard coin.txOut.value >= 0 && coin.txOut.value <= BitcoinTx.maxMoney else {
                throw .inputValueOutOfRange
            }
            guard valueInAcc >= 0 && valueInAcc <= BitcoinTx.maxMoney else {
                throw .inputValueOutOfRange
            }
        }
        valueIn = valueInAcc

        // This is guaranteed by calling Tx.check() before this function.
        precondition(tx.valueOut >= 0 && tx.valueOut <= BitcoinTx.maxMoney)

        guard valueIn >= tx.valueOut else {
            throw .inputsValueBelowOutput
        }

        let fee = valueIn - tx.valueOut
        guard fee >= 0 && fee <= BitcoinTx.maxMoney else {
            throw .feeOutOfRange
        }
    }

    private func calculateFees(_ tx: BitcoinTx, exclude: [TxOutpoint], auxCoins: [TxOutpoint : UnspentOut]) async -> SatoshiAmount {
        precondition(!tx.isCoinbase)
        var valueIn = SatoshiAmount(0)
        for txIn in tx.ins {
            let outpoint = txIn.outpoint

            guard let coin = await coins.get(outpoint) ?? auxCoins[outpoint] else {
                preconditionFailure()
            }
            valueIn += coin.txOut.value
        }
        return valueIn - tx.valueOut
    }

    private func checkTx(_ tx: BitcoinTx, exclude: [TxOutpoint]? = .none, auxCoins: [TxOutpoint : UnspentOut]? = .none) async -> Bool {
        let exclude = exclude ?? mempoolExclude
        let auxCoins = auxCoins ?? mempoolCoins

        // Check tx
        do {
            try tx.check(weightLimit: ConsensusParams.maxBlockWeight)
            if !tx.isCoinbase {
                try await checkTxIns(tx, exclude: exclude, auxCoins: auxCoins)
            }

            // TODO: `checkSequenceLocks(tx, verifyLockTimeSequence: Bool, coins: [TxOutpoint : UnspentOut], previousBlockMedianTimePast: Int)`
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
            var prevouts = [TxOut]()
            for txin in tx.ins {
                guard let coin = await coins.get(txin.outpoint) ?? auxCoins[txin.outpoint] else {
                    preconditionFailure() // Already checked in checkTxIns
                }
                prevouts.append(coin.txOut)
            }
            if !tx.verifyScript(prevouts: prevouts) {
                return false // error, failed to verify tx
            }
        }
        return true
    }

    private func connectBlock(_ block: TxBlock) async {
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

        // Remove available coins
        for tx in block.txs {
            // Remove coins
            for txin in tx.ins {
                try! await coins.remove(txin.outpoint)
            }
            // Add coins
            for out in tx.outs.enumerated() {
                await coins.add(.init(out.element, height: blockRef.height, isCoinbase: tx.isCoinbase), for: .init(tx: tx.id, txOut: out.offset))
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

    public func processBlock(_ block: TxBlock) async throws(Error) {

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
            throw .wrongMerkleRooot
        }

        var tmpExclude = [TxOutpoint]()
        var tmpCoins = [TxOutpoint: UnspentOut]()
        guard let coinbaseTx = block.txs.first, coinbaseTx.isCoinbase else {
            throw .missingCoinbaseTransaction
        }
        var fees = SatoshiAmount(0)
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
                tmpCoins[.init(tx: txid, txOut: out.offset)] = .init(out.element, height: nextTipHeight, isCoinbase: tx.isCoinbase)
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
        precondition(unclaimed >= 0 && unclaimed <= BitcoinTx.maxMoney) // coinbase "fee" our of range, can this ever happen??

        await connectBlock(block) // Will update chain tip and coins

        // Clean up mempool and mempoolCoins
        var newMempool = [BitcoinTx]()
        var mpExclude = [TxOutpoint]()
        var mpCoins = [TxOutpoint: UnspentOut]()
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
                mpCoins[.init(tx: txid, txOut: out.offset)] = .init(out.element)
            }
        }
        mempool = newMempool
        mempoolExclude = mpExclude
        mempoolCoins = mpCoins
    }

    @discardableResult public func generateToScript(_ script: BitcoinScript, blocks: Int = 1, maxTries: Int = Config.defaultMaxTries, blockTime: Date? = .none) async -> [BlockID] {
        var ids = [BlockID]()
        for _ in 0 ..< blocks {
            if let block = await generateTo(script, maxTries: maxTries, blockTime: blockTime ?? .now) {
                ids.append(block.id)
            }
        }
        return ids
    }

    @discardableResult public func generateTo(_ pubkey: PubKey, blockTime: Date = .now) async -> TxBlock? {
        logger.info("Generating blocks with coinbase reward going to public key.")
        return await generateTo(BitcoinScript.payToPubkeyHash(pubkey), blockTime: blockTime)
    }

    /// Generates a block using the mempool transactions and locks the coinbase reward output to the provided public key hash.
    ///
    /// This function essentially mines a block in current thread so it has the potential to completely block. Future versions of this method will provide asynchronous control via detached background task.
    @discardableResult public func generateTo(_ script: BitcoinScript, maxTries: Int = Config.defaultMaxTries, blockTime: Date = .now) async -> TxBlock? {
        logger.info("Generating blocks with coinbase reward going to public key hash.")

        guard await synchronized else {
            // Waiting for pending block transactions for known headers
            preconditionFailure("Chain cannot contain unvalidated blocks.")
        }
        let chainTipRef = await blockIndex.get(chainTip)
        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)

        let mempoolTxs = mempool

        // Calculate fees
        var totalFees = SatoshiAmount(0)
        for tx in mempoolTxs {
            totalFees += await calculateFees(tx, exclude: [], auxCoins: mempoolCoins) // TODO: Double-check `exclude` needs to be empty as well as the auxCoins parameter.
        }

        let blockReward = params.blockSubsidy + totalFees
        let coinbaseTx = BitcoinTx.makeCoinbaseTx(blockHeight: chainTipRef.height + 1, out: .init(value: blockReward, script: script), witnessMerkleRoot: witnessMerkleRoot)

        let previousBlockHash = chainTip!
        let txs = [coinbaseTx] + mempoolTxs
        let merkleRoot = calculateMerkleRoot(txs)

        let target = await getNextWorkRequired(forHeight: chainTipRef.height, newBlockTime: blockTime, params: params)

        var nonce = 0
        var tries = maxTries
        var block: TxBlock
        repeat {
            block = .init(
                version: 0x20000000,
                previous: previousBlockHash,
                merkleRoot: merkleRoot,
                time: blockTime,
                target: target,
                nonce: nonce
            )
            nonce += 1
            tries -= 1
        } while tries > 0 && (try! DifficultyTarget(binaryData: block.hash) > DifficultyTarget(compact: target))

        guard try! DifficultyTarget(binaryData: block.hash) <= DifficultyTarget(compact: target) else {
            return .none
        }

        block.txs = txs

        // Reset mempool
        mempool = []
        mempoolExclude = []
        mempoolCoins = [:]

        await connectBlock(block)
        return block
    }

    public func calculateMissingTxs(ids: [TxID]) async -> [TxID] {
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

    public func calculateMissingBlocks(ids: [BlockID]) async -> [BlockID] {
        await blockIndex.calculateMissingBlocks(ids)
    }

    /// Gets a transaction by ID looking into mempool and blocks.
    public func getTx(_ id: TxID) async -> BitcoinTx? {
        await getTxs([id]).first
    }

    /// Finds transactions in mempool and blocks which match any of the provided IDs.
    public func getTxs(_ ids: [TxID]) async -> [BitcoinTx] {
        var ret = [BitcoinTx]()
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
    public func findMempoolTxs(shortIDs: [UInt64], header: TxBlock, nonce: UInt64) -> [BitcoinTx?] {
        let (first, second) = header.makeShortIDParams(nonce: nonce)
        let mempoolShortIDs = mempool.map { tx in tx.makeShortTxID(nonce: nonce, first: first, second: second)}
        return shortIDs.map { id in
            guard let i = mempoolShortIDs.firstIndex(of: id) else {
                return .none
            }
            return mempool[i]
        }
    }

    private func getNextWorkRequired(forHeight heightLast: Int, newBlockTime: Date, params: ConsensusParams) async -> Int {
        precondition(heightLast >= 0)
        let lastHeader = await blockIndex.get(at: heightLast)
        let powLimitTarget = try! DifficultyTarget(binaryData: Data(params.powLimit.reversed()))
        let proofOfWorkLimit = powLimitTarget.toCompact()

        // Only change once per difficulty adjustment interval
        if (heightLast + 1) % params.difficultyAdjustmentInterval != 0 {
            if params.powAllowMinDifficultyBlocks {
                // Special difficulty rule for testnet:
                // If the new block's timestamp is more than 2* 10 minutes
                // then allow mining of a min-difficulty block.
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
        return calculateNextWorkRequired(lastHeader: lastHeader, firstBlockTime: firstHeader.time, params: params)
    }

    private func calculateNextWorkRequired(lastHeader: BlockRef, firstBlockTime: Date, params: ConsensusParams) -> Int {
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
        let powLimitTarget = try! DifficultyTarget(binaryData: Data(params.powLimit.reversed()))

        var new = DifficultyTarget(compact: lastHeader.target)
        precondition(!new.isZero)
        new *= (UInt32(actualTimespan))
        new /= DifficultyTarget(UInt64(params.powTargetTimespan))

        if new > powLimitTarget { new = powLimitTarget }

        return new.toCompact()
    }

    private func getBlockSubsidy(_ height: Int) -> SatoshiAmount {
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

    private func getMedianTimePast(at height: Int? = .none) async -> Date {
        let maxHeight = await blockIndex.get(chainTip).height
        let height = height ?? maxHeight
        precondition(height >= 0 && height <= maxHeight)
        let startHeight = max(height - 11, 0)
        let blockRefs = await blockIndex.get(from: startHeight, to: height)
        let median = blockRefs.map(\.time).sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }

    private func guessVerificationProgress(for height: Int? = .none) async -> Double {
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
        if chainTip == .none { return true }

        let blockRef = await blockIndex.get(chainTip)

        if try! DifficultyTarget(binaryData: params.minChainwork.reversed()) > blockRef.chainwork { return true }

        let maxTipAge = TimeInterval(24 * 60 * 60) // 24 hours
        let maxTipTime = Date(timeIntervalSince1970: nowSeconds() - maxTipAge)
        if (blockRef.time < maxTipTime ) { return true }

        logger.info("Leaving InitialBlockDownload (latching to false)")
        finishedIDB.store(true, ordering: .relaxed)
        return false
    }

    /// BIP68 - Untested - Entrypoint 1.
    private func checkSequenceLocks(_ tx: BitcoinTx, verifyLockTimeSequence: Bool, coins: [TxOutpoint : UnspentOut], previousBlockMedianTimePast: Int) async throws {
        // CheckSequenceLocks() uses chainActive.Height()+1 to evaluate
        // height based locks because when SequenceLocks() is called within
        // ConnectBlock(), the height of the block *being*
        // evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the
        // *next* block, we need to use one more than chainActive.Height()
        let nextBlockHeight = await blockIndex.get(chainTip).height + 1
        var heights = [Int]()
        // pcoinsTip contains the UTXO set for chainActive.Tip()
        for txIn in tx.ins {
            guard let coin = coins[txIn.outpoint] else {
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
