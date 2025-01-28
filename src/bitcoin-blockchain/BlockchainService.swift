import Foundation
import AsyncAlgorithms
import BitcoinCrypto
import BitcoinBase

public actor BlockchainService: Sendable {

    public enum Error: Swift.Error {
        case unsupportedBlockVersion, orphanHeader, insuficientProofOfWork, headerTooOld, headerTooNew
    }

    let params: ConsensusParams

    public private(set) var blocks = [TxBlock]()
    public private(set) var tip = 0

    public private(set) var mempool = [BitcoinTx]()

    private var coins = [TxOutpoint: UnspentOut]()
    private var mempoolExclude = [TxOutpoint]()
    private var mempoolCoins = [TxOutpoint: UnspentOut]()

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<TxBlock>]()

    /// Subscriptions to new transactions.
    private var txChannels = [AsyncChannel<BitcoinTx>]()

    public init(params: ConsensusParams = .regtest) {
        self.params = params
        let genesisBlock = TxBlock.makeGenesisBlock(params: params)
        blocks.append(genesisBlock)
        tip += 1
    }

    public var genesisBlock: TxBlock {
        blocks[0]
    }

    public var synchronized: Bool {
        tip == blocks.count
    }
    
    public func getBlock(_ height: Int) -> TxBlock {
        precondition(height < tip)
        return blocks[height]
    }

    public func getHeader(_ id: BlockID) -> TxBlock? {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else {
            return .none
        }
        return blocks[index]
    }

    public func getBlock(_ id: BlockID) -> TxBlock? {
        guard let index = blocks.firstIndex(where: { $0.id == id }), index < tip else {
            return .none
        }
        return blocks[index]
    }

    /// Adds a transaction to the mempool.
    public func addTx(_ tx: BitcoinTx) throws {
        guard !mempool.contains(tx) else { return }
        guard checkTx(tx) else { return }
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

    public func shutdown() {
        for channel in blockChannels {
            channel.finish()
        }
        for channel in txChannels {
            channel.finish()
        }
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
    public func makeBlockLocator() -> [Data] {
        precondition(!blocks.isEmpty)

        var have = [Data]()
        var index = blocks.endIndex - 1
        var step = 1
        while index >= 0 {
            let header = blocks[index]
            have.append(header.id)
            if index == 0 { break }

            // Exponentially larger steps back, plus the genesis block.
            if have.count >= 10 { step *= 2 }
            index = max(index - step, 0) // TODO: Use "skiplist"
        }
        return have
    }

    public func findHeaders(using locator: [Data]) -> [TxBlock] {
        var from = Int?.none
        for id in locator {
            for index in blocks.indices {
                let header = blocks[index]
                if header.id == id {
                    from = index
                    break
                }
            }
            if from != .none { break }
        }
        guard let from else { return [] }
        let firstIndex = from.advanced(by: 1)
        var lastIndex = tip
        if firstIndex >= lastIndex { return [] }
        if lastIndex - firstIndex > 200 {
            lastIndex = from.advanced(by: 200)
        }
        var headers = [TxBlock]()
        for var block in blocks[firstIndex ..< lastIndex] {
            block.txs = []
            headers.append(block)
        }
        return headers
    }

    private func checkHeader(_ header: inout TxBlock) throws(Error) {
        guard header.version == 0x20000000 else {
            throw .unsupportedBlockVersion
        }

        let lastHeader = blocks.last!
        guard lastHeader.id == header.previous else {
            throw .orphanHeader
        }

        guard header.time >= getMedianTimePast() else {
            throw .headerTooOld
        }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        guard header.time <= calendar.date(byAdding: .hour, value: 2, to: .now)! else {
            throw .headerTooNew
        }

        let target = getNextWorkRequired(forHeight: blocks.endIndex.advanced(by: -1), newBlockTime: header.time, params: params)
        guard DifficultyTarget(compact: header.target) <= DifficultyTarget(compact: target), DifficultyTarget(header.hash) <= DifficultyTarget(compact: header.target) else {
            throw .insuficientProofOfWork
        }
        let chainwork = lastHeader.work + header.work
        header.context = .init(height: blocks.count, chainwork: chainwork, status: .header)
    }

    public func processHeaders(_ headers: [TxBlock]) throws(Error) {
        for var header in headers {
            guard header != blocks.last!.header else {
                continue
            }
            try checkHeader(&header)
            blocks.append(header)
        }
    }

    public func getNextMissingBlocks(_ numberOfBlocks: Int) -> [Data] {
        let delta = blocks.count - tip
        let realNumberOfBlocks = min(numberOfBlocks, delta)
        var hashes = [Data]()
        for i in tip ..< (tip + realNumberOfBlocks) {
            hashes.append(blocks[i].id)
        }
        return hashes
    }

    public func getBlocks(_ hashes: [Data]) -> [TxBlock] {
        var ret = [TxBlock]()
        for hash in hashes {
            guard let index = blocks.firstIndex(where: { $0.id == hash }),
                  index < tip else {
                continue
            }
            ret.append(blocks[index])
        }
        return ret
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``check()``
    private func checkTxIns(_ tx: BitcoinTx, exclude: [TxOutpoint], auxCoins: [TxOutpoint : UnspentOut]) throws(TxError) {

        let valueIn: SatoshiAmount
        if tx.isCoinbase {
            valueIn = getBlockSubsidy(tip)
        } else {
            var valueInAcc = SatoshiAmount(0)
            for txIn in tx.ins.enumerated() {
                let outpoint = txIn.element.outpoint

                // are the actual inputs available?
                guard let coin = coins[outpoint] ?? auxCoins[outpoint], !exclude.contains(outpoint) else {
                    throw .inputMissingOrSpent
                }
                guard !coin.isCoinbase || tip - coin.height >= params.coinbaseMaturity else {
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
        }

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

    private func checkTx(_ tx: BitcoinTx, exclude: [TxOutpoint]? = .none, auxCoins: [TxOutpoint : UnspentOut]? = .none) -> Bool {
        let exclude = exclude ?? mempoolExclude
        let auxCoins = auxCoins ?? mempoolCoins

        // Check tx
        do {
            try tx.check(weightLimit: ConsensusParams.maxBlockWeight)
            try checkTxIns(tx, exclude: exclude, auxCoins: auxCoins)


            // TODO: `checkSequenceLocks(tx, verifyLockTimeSequence: Bool, coins: [TxOutpoint : UnspentOut], previousBlockMedianTimePast: Int)`
        } catch {
            return false
        }

        // TODO: Enforce BIP113 (Median Time Past) for block validation only (not mempool acceptance)
        // let enforceLocktimeMedianTimePast = deploymentActiveAfter(blocks[tip], chainman, Consensus.deploymentCSV)
        // let lockTimeCutoff = enforceLocktimeMedianTimePast ? Int(getMedianTimePast(for: tip).timeIntervalSince1970)) : blockCandidate.time

        // Check that all transactions are finalized
        guard tx.isFinal(blockHeight: tip, blockTime: Int(getMedianTimePast().timeIntervalSince1970)) else {
            // TODO: `throw BlockValidationError.nonFinalTransaction` or the like.
            return false
        }

        if !tx.isCoinbase {
            var prevouts = [TxOut]()
            for txin in tx.ins {
                guard let coin = coins[txin.outpoint] ?? auxCoins[txin.outpoint] else {
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

    private func connectBlock(_ block: TxBlock) {
        var block = block
        let chainwork = blocks[tip - 1].work + block.work
        block.context =  .init(height: tip, chainwork: chainwork, status: .full)

        // Add block
        if tip < blocks.count {
            blocks[tip] = block
        } else {
            blocks.append(block)
        }

        // Remove available coins
        for tx in block.txs {
            // Remove coins
            for txin in tx.ins {
                coins[txin.outpoint] = nil
            }
            // Add coins
            for out in tx.outs.enumerated() {
                coins[.init(tx: tx.id, txOut: out.offset)] = .init(out.element, height: tip, isCoinbase: tx.isCoinbase)
            }
        }

        // Update tip
        tip += 1

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

    public func processBlock(_ block: TxBlock) throws(Error) {

        if tip < blocks.count && block.dataHeaderOnly != blocks[tip].dataHeaderOnly {
            // New block does not match pre-existing header for block:
            //   Replace block entirely and remove all headers
            blocks.removeLast(blocks.count - tip)
        }

        var block = block
        if tip == blocks.count {
            // We need to check the header fields
            try checkHeader(&block)
        }

        // Verify merkle root
        let expectedMerkleRoot = calculateMerkleRoot(block.txs)
        guard block.merkleRoot == expectedMerkleRoot else {
            return
        }

        var tmpExclude = [TxOutpoint]()
        var tmpCoins = [TxOutpoint: UnspentOut]()
        for tx in block.txs {
            guard checkTx(tx, exclude: tmpExclude, auxCoins: tmpCoins) else {
                return // Error, invalid tx in block
            }
            // Remove coins
            tmpExclude += tx.ins.map(\.outpoint)
            // Add coins
            let txid = tx.id
            for out in tx.outs.enumerated() {
                tmpCoins[.init(tx: txid, txOut: out.offset)] = .init(out.element, height: tip, isCoinbase: tx.isCoinbase)
            }
        }

        connectBlock(block) // Will update coins

        // Clean up mempool and mempoolCoins
        var newMempool = [BitcoinTx]()
        var mpExclude = [TxOutpoint]()
        var mpCoins = [TxOutpoint: UnspentOut]()
        for tx in mempool {
            guard checkTx(tx, exclude: mpExclude, auxCoins: mpCoins) else {
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

    public func generateTo(_ pubkey: PubKey, blockTime: Date = .now) {
        generateTo(Data(Hash160.hash(data: pubkey.data)), blockTime: blockTime)
    }

    public func generateTo(_ pubkeyHash: Data, blockTime: Date = .now) {
        precondition(!blocks.isEmpty)

        guard tip == blocks.count else {
            // Waiting for pending block transactions for known headers
            return
        }

        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)
        let coinbaseTx = BitcoinTx.makeCoinbaseTx(blockHeight: tip, pubkeyHash: pubkeyHash, witnessMerkleRoot: witnessMerkleRoot, blockSubsidy: params.blockSubsidy)

        let previousBlockHash = blocks.last!.id
        let txs = [coinbaseTx] + mempool
        let merkleRoot = calculateMerkleRoot(txs)

        let target = getNextWorkRequired(forHeight: tip - 1, newBlockTime: blockTime, params: params)

        var nonce = 0
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
        } while DifficultyTarget(block.hash) > DifficultyTarget(compact: target)

        block.txs = txs

        // Reset mempool
        mempool = []
        mempoolExclude = []
        mempoolCoins = [:]

        connectBlock(block)
    }

    public func calculateMissingTxs(ids: [TxID]) -> [TxID] {
        var newIDs = ids
        for tx in mempool {
            if ids.contains(tx.id) {
                newIDs.removeAll { $0 == tx.id }
            }
        }
        for block in blocks {
            for tx in block.txs {
                if ids.contains(tx.id) {
                    newIDs.removeAll { $0 == tx.id }
                }
            }
        }
        return newIDs
    }

    public func calculateMissingBlocks(ids: [BlockID]) -> [BlockID] {
        var newIDs = ids
        for block in blocks {
            if ids.contains(block.id) {
                newIDs.removeAll { $0 == block.id }
            }
        }
        return newIDs
    }

    /// Gets a transaction by ID looking into mempool and blocks.
    public func getTx(_ id: TxID) -> BitcoinTx? {
        getTxs([id]).first
    }

    /// Finds transactions in mempool and blocks which match any of the provided IDs.
    public func getTxs(_ ids: [TxID]) -> [BitcoinTx] {
        var ret = [BitcoinTx]()
        for tx in mempool {
            if ids.contains(tx.id) {
                ret.append(tx)
            }
        }
        for block in blocks {
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

    private func getNextWorkRequired(forHeight heightLast: Int, newBlockTime: Date, params: ConsensusParams) -> Int {
        precondition(heightLast >= 0)
        let lastHeader = blocks[heightLast]
        let powLimitTarget = DifficultyTarget(Data(params.powLimit.reversed()))
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
                        header = blocks[height]
                    }
                    return header.target
                }
            }
            return lastHeader.target
        }

        // Go back by what we want to be 14 days worth of blocks
        let heightFirst = heightLast - (params.difficultyAdjustmentInterval - 1)
        precondition(heightFirst >= 0)
        let firstHeader = blocks[heightFirst] // pindexLast->GetAncestor(nHeightFirst)
        return calculateNextWorkRequired(lastHeader: lastHeader, firstBlockTime: firstHeader.time, params: params)
    }

    private func calculateNextWorkRequired(lastHeader: TxBlock, firstBlockTime: Date, params: ConsensusParams) -> Int {
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
        let powLimitTarget = DifficultyTarget(Data(params.powLimit.reversed()))

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

    private func getMedianTimePast(for height: Int? = .none) -> Date {
        let height = height ?? tip - 1
        precondition(height >= 0 && height < blocks.count)
        let start = max(height - 11, 0)
        let median = blocks.lazy.map(\.time)[start...height].sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }

    /// BIP68 - Untested - Entrypoint 1.
    private func checkSequenceLocks(_ tx: BitcoinTx, verifyLockTimeSequence: Bool, coins: [TxOutpoint : UnspentOut], previousBlockMedianTimePast: Int) throws {
        // CheckSequenceLocks() uses chainActive.Height()+1 to evaluate
        // height based locks because when SequenceLocks() is called within
        // ConnectBlock(), the height of the block *being*
        // evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the
        // *next* block, we need to use one more than chainActive.Height()
        let nextBlockHeight = tip // chainTip + 1
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
