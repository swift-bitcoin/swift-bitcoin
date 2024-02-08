import Foundation
import BitcoinCrypto

public actor BitcoinService {

    let consensusParameters: ConsensusParameters
    public private(set) var blockchain = [TransactionBlock]()
    public private(set) var mempool = [BitcoinTransaction]()

    public init(consensusParameters: ConsensusParameters = .regtest) {
        self.consensusParameters = consensusParameters
    }

    public var genesisBlock: TransactionBlock {
        blockchain[0]
    }

    public func addTransaction(_ transaction: BitcoinTransaction) {
        mempool.append(transaction)
    }

    public func createGenesisBlock() {
        guard blockchain.isEmpty else { return }
        blockchain.append(TransactionBlock.makeGenesisBlock(consensusParameters: consensusParameters))
    }

    public func generateTo(_ address: String, blockTime: Date = .now) {
        if blockchain.isEmpty {
            createGenesisBlock()
        }

        guard let addressData = Base58.base58CheckDecode(address),
              addressData[addressData.startIndex] == Int8(WalletNetwork.regtest.base58Version)
        else { return }

        let destinationPublicKeyHash = addressData[addressData.startIndex.advanced(by: 1)...]

        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)
        let coinbaseTx = BitcoinTransaction.makeCoinbaseTransaction(blockHeight: blockchain.count, destinationPublicKeyHash: destinationPublicKeyHash, witnessMerkleRoot: witnessMerkleRoot, consensusParameters: consensusParameters)

        let previousBlockHash = blockchain.last!.identifier
        let blockTransactions = [coinbaseTx] + mempool
        let merkleRoot = calculateMerkleRoot(blockTransactions)

        let target = getNextWorkRequired(forHeight: blockchain.endIndex.advanced(by: -1), newBlockTime: blockTime, params: consensusParameters)

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
                transactions: blockTransactions)
            nonce += 1
        } while DifficultyTarget(block.hash) > DifficultyTarget(compact: target)

        blockchain.append(block)
        mempool = .init()
    }

    private func getNextWorkRequired(forHeight heightLast: Int, newBlockTime: Date, params: ConsensusParameters) -> Int {
        precondition(heightLast >= 0)
        let lastBlock = blockchain[heightLast]
        let powLimitTarget = DifficultyTarget(Data(params.powLimit.reversed()))
        let proofOfWorkLimit = powLimitTarget.toCompact()

        // Only change once per difficulty adjustment interval
        if (heightLast + 1) % params.difficultyAdjustmentInterval != 0 {
            if params.powAllowMinDifficultyBlocks {
                // Special difficulty rule for testnet:
                // If the new block's timestamp is more than 2* 10 minutes
                // then allow mining of a min-difficulty block.
                if Int(newBlockTime.timeIntervalSince1970) > Int(lastBlock.header.time.timeIntervalSince1970) + params.powTargetSpacing * 2 {
                    return proofOfWorkLimit
                } else {
                    // Return the last non-special-min-difficulty-rules-block
                    var height = heightLast
                    var block = lastBlock
                    while height > 0 && height % params.difficultyAdjustmentInterval != 0 && block.header.target == proofOfWorkLimit {
                        height -= 1
                        block = blockchain[height]
                    }
                    return block.header.target
                }
            }
            return lastBlock.header.target
        }

        // Go back by what we want to be 14 days worth of blocks
        let heightFirst = heightLast - (params.difficultyAdjustmentInterval - 1)
        precondition(heightFirst >= 0)
        let firstBlock = blockchain[heightFirst] // pindexLast->GetAncestor(nHeightFirst)
        return calculateNextWorkRequired(lastBlock: lastBlock, firstBlockTime: firstBlock.header.time, params: params)
    }

    private func calculateNextWorkRequired(lastBlock: TransactionBlock, firstBlockTime: Date, params: ConsensusParameters) -> Int {
        if params.powNoRetargeting {
            return lastBlock.header.target
        }

        // Limit adjustment step
        var actualTimespan = Int(lastBlock.header.time.timeIntervalSince1970) - Int(firstBlockTime.timeIntervalSince1970)
        if actualTimespan < params.powTargetTimespan / 4 {
            actualTimespan = params.powTargetTimespan / 4
        }
        if actualTimespan > params.powTargetTimespan * 4 {
            actualTimespan = params.powTargetTimespan * 4
        }

        // Retarget
        let powLimitTarget = DifficultyTarget(Data(params.powLimit.reversed()))

        var new = DifficultyTarget(compact: lastBlock.header.target)
        precondition(!new.isZero)
        new *= (UInt32(actualTimespan))
        new /= DifficultyTarget(UInt64(params.powTargetTimespan))

        if new > powLimitTarget { new = powLimitTarget }

        return new.toCompact()
    }
}
