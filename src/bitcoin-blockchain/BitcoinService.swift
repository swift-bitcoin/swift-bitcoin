import Foundation
import AsyncAlgorithms
import BitcoinCrypto
import BitcoinBase

public actor BitcoinService: Sendable {

    public enum Error: Swift.Error {
        case unsupportedBlockVersion, orphanHeader, insuficientProofOfWork, headerTooOld, headerTooNew
    }

    let consensusParams: ConsensusParams
    public private(set) var headers = [BlockHeader]()
    public private(set) var blockTransactions = [[BitcoinTransaction]]()
    public private(set) var mempool = [BitcoinTransaction]()

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<TransactionBlock>]()

    public init(consensusParams: ConsensusParams = .regtest) {
        self.consensusParams = consensusParams
        let genesisBlock = TransactionBlock.makeGenesisBlock(consensusParams: consensusParams)
        headers.append(genesisBlock.header)
        blockTransactions.append(genesisBlock.transactions)
    }

    public var genesisBlock: TransactionBlock {
        .init(header: headers[0], transactions: blockTransactions[0])
    }

    public func getBlock(_ height: Int) -> TransactionBlock {
        precondition(height < blockTransactions.count)
        return .init(header: headers[height], transactions: blockTransactions[height])
    }

    /// Adds a transaction to the mempool.
    public func addTransaction(_ transaction: BitcoinTransaction) {
        // TODO: Check transaction.
        mempool.append(transaction)
    }

    public func createGenesisBlock() {
        guard blockTransactions.isEmpty else { return }
        let genesisBlock = TransactionBlock.makeGenesisBlock(consensusParams: consensusParams)
        headers.append(genesisBlock.header)
        blockTransactions.append(genesisBlock.transactions)
    }

    public func subscribeToBlocks() -> AsyncChannel<TransactionBlock> {
        blockChannels.append(.init())
        return blockChannels.last!
    }

    public func shutdown() {
        for channel in blockChannels {
            channel.finish()
        }
    }

    public func unsubscribe(_ channel: AsyncChannel<TransactionBlock>) {
        channel.finish()
        blockChannels.removeAll(where: { $0 === channel })
    }

    /// To create the block locator hashes, keep pushing hashes until you go back to the genesis block. After pushing 10 hashes back, the step backwards doubles every loop.
    public func makeBlockLocator() -> [Data] {
        precondition(headers.startIndex == 0)

        var index = headers.endIndex - 1
        var step = 1
        var have = [Data]()
        if index < 0 { return have }

        while index >= 0 {
            let header = headers[index]
            have.append(header.identifier)
            if index == 0 { break }

            // Exponentially larger steps back, plus the genesis block.
            index = max(index - step, 0) // TODO: Use "skiplist"
            if have.count > 10 { step *= 2 }
        }
        return have
    }

    public func findHeaders(using locator: [Data]) -> [BlockHeader] {
        var from = Int?.none
        for identifier in locator {
            for index in headers.indices.reversed() {
                let header = headers[index]
                if header.identifier == identifier {
                    from = index
                    break
                }
            }
            if from != .none { break }
        }
        guard let from else { return [] }
        let firstIndex = from.advanced(by: 1)
        var lastIndex = blockTransactions.endIndex
        if firstIndex >= lastIndex { return [] }
        if lastIndex - firstIndex > 200 {
            lastIndex = from.advanced(by: 200)
        }
        return .init(headers[firstIndex ..< lastIndex])
    }

    public func processHeaders(_ newHeaders: [BlockHeader]) throws {
        for newHeader in newHeaders {

            guard newHeader.version == 0x20000000 else {
                throw Error.unsupportedBlockVersion
            }


            let lastVerifiedHeader = headers.last!
            guard lastVerifiedHeader.identifier == newHeader.previous else {
                throw Error.orphanHeader
            }

            guard newHeader.time > getMedianTimePast() else {
                throw Error.headerTooOld
            }

            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = .gmt
            guard newHeader.time <= calendar.date(byAdding: .hour, value: 2, to: .now)! else {
                throw Error.headerTooNew
            }

            let target = getNextWorkRequired(forHeight: blockTransactions.endIndex.advanced(by: -1), newBlockTime: newHeader.time, params: consensusParams)
            guard DifficultyTarget(compact: newHeader.target) <= DifficultyTarget(compact: target), DifficultyTarget(newHeader.hash) <= DifficultyTarget(compact: newHeader.target) else {
                throw Error.insuficientProofOfWork
            }
            headers.append(newHeader)
        }
    }

    public func generateTo(_ destinationPublicKey: Data, blockTime: Date = .now) {
        if blockTransactions.isEmpty {
            createGenesisBlock()
        }

        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)
        let coinbaseTx = BitcoinTransaction.makeCoinbaseTransaction(blockHeight: blockTransactions.count, destinationPublicKey: destinationPublicKey, witnessMerkleRoot: witnessMerkleRoot, blockSubsidy: consensusParams.blockSubsidy)

        let previousBlockHash = headers.last!.identifier
        let transactions = [coinbaseTx] + mempool
        let merkleRoot = calculateMerkleRoot(transactions)

        let target = getNextWorkRequired(forHeight: blockTransactions.endIndex.advanced(by: -1), newBlockTime: blockTime, params: consensusParams)

        var nonce = 0
        var block: TransactionBlock
        repeat {
            block = TransactionBlock(
                header: .init(
                    version: 0x20000000,
                    previous: previousBlockHash,
                    merkleRoot: merkleRoot,
                    time: blockTime,
                    target: target,
                    nonce: nonce
                ),
                transactions: transactions)
            nonce += 1
        } while DifficultyTarget(block.hash) > DifficultyTarget(compact: target)

        let blockFound = block
        headers.append(blockFound.header)
        blockTransactions.append(blockFound.transactions)
        mempool = .init()

        Task {
            await withDiscardingTaskGroup {
                for channel in blockChannels {
                    $0.addTask {
                        await channel.send(blockFound)
                    }
                }
            }
        }
    }

    private func getNextWorkRequired(forHeight heightLast: Int, newBlockTime: Date, params: ConsensusParams) -> Int {
        precondition(heightLast >= 0)
        let lastHeader = headers[heightLast]
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
                        header = headers[height]
                    }
                    return header.target
                }
            }
            return lastHeader.target
        }

        // Go back by what we want to be 14 days worth of blocks
        let heightFirst = heightLast - (params.difficultyAdjustmentInterval - 1)
        precondition(heightFirst >= 0)
        let firstHeader = headers[heightFirst] // pindexLast->GetAncestor(nHeightFirst)
        return calculateNextWorkRequired(lastHeader: lastHeader, firstBlockTime: firstHeader.time, params: params)
    }

    private func calculateNextWorkRequired(lastHeader: BlockHeader, firstBlockTime: Date, params: ConsensusParams) -> Int {
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

    // TODO: Pattern that the region based isolation checker does not understand how to check. Please file a bug
    private func getMedianTimePast() -> Date {
        getMedianTimePast(for: .none)
    }

    private func getMedianTimePast(for height: Int? = .none) -> Date {
        let height = height ?? headers.count - 1
        precondition(height >= 0 && height < headers.count)
        let start = max(height - 11, 0)
        let median = headers.lazy.map(\.time)[start...height].sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }
}
