import Foundation
import BitcoinCrypto

fileprivate let blockSubsidy = 50 * 100_000_000

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

    public var bits: Int {
        // TODO: Calculate difficulty based on blockchain history #135
        0x207fffff // Max target (compact) for regtest. For main it would be 0x1d00ffff
    }

    public func createGenesisBlock() {
        guard blockchain.isEmpty else { return }

        let blockTime = Date(timeIntervalSince1970: 1296688602) // For regtest, would be 1231006505 for mainnet
        let nonce = 2 // For regtest. Would be 2083236893 for mainnet
        let bits = 0x207fffff // For regtest. For main it would be 0x1d00ffff

        let satoshiPublicKey = "04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f"
        let genesisMessage = "The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"

        let genesisTx = BitcoinTransaction(
            version: .v1,
            inputs: [.init(
                outpoint: .coinbase,
                sequence: .final,
                script: .init([
                    .pushBytes(Data([0xff, 0xff, 0x00, 0x1d])),
                    .pushBytes(Data([0x04])),
                    .pushBytes(genesisMessage.data(using: .ascii)!)
                ]))],
            outputs: [
                .init(value: blockSubsidy,
                      script: .init([
                        .pushBytes(.init(hex: satoshiPublicKey)!),
                        .checkSig]))
            ])

        let genesisBlock = TransactionBlock(
            header: .init(
                version: 1,
                previous: Data(repeating: 0, count: 32),
                merkleRoot: genesisTx.identifier,
                time: blockTime,
                target: bits,
                nonce: nonce
            ),
            transactions: [genesisTx])

        blockchain.append(genesisBlock)
    }

    public func generateTo(_ address: String, blockTime: Date = .now) {
        if blockchain.isEmpty {
            createGenesisBlock()
        }

        guard let addressData = Base58.base58CheckDecode(address),
              addressData[addressData.startIndex] == Int8(WalletNetwork.regtest.base58Version)
        else { return }

        let destinationPublicKeyHash = addressData[addressData.startIndex.advanced(by: 1)...]

        // BIP141 Commitment Structure https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#commitment-structure
        let witnessReservedValue = Data(repeating: 0, count: 32)
        let coinbaseTxIdentifier = Data(repeating: 0, count: 32)

        let witnessCommitmentHeader = Data([0xaa, 0x21, 0xa9, 0xed])
        let witnessRootHash = coinbaseTxIdentifier // Merkle root
        let witnessCommitmentHash = hash256(witnessRootHash + witnessReservedValue)

        let witnessCommitmentScript = BitcoinScript([
            .return,
            .pushBytes(witnessCommitmentHeader + witnessCommitmentHash),
        ])

        let blockHeight = blockchain.count
        let coinbaseTx = BitcoinTransaction(version: .v2, inputs: [
            .init(outpoint: .coinbase, sequence: .final, script: .init([.encodeMinimally(blockHeight), .zero]), witness: .init([witnessReservedValue]))
        ], outputs: [
            .init(value: blockSubsidy, script: .init([
                .dup,
                .hash160,
                .pushBytes(destinationPublicKeyHash),
                .equalVerify,
                .checkSig
            ])),
            .init(value: 0, script: witnessCommitmentScript)
        ])

        let previousBlockHash = blockchain.last!.identifier
        let blockTransactions = [coinbaseTx] + mempool
        let merkleRoot = calculateMerkleRoot(blockTransactions)

        var neg: Bool = true
        var over: Bool = true
        let target = Arithmetic256.fromCompact(bits, negative: &neg, overflow: &over)
        if Arithmetic256.isZero(target) || neg || over {
            preconditionFailure()
        }

        let nextTarget = getNextWorkRequired(forHeight: blockchain.endIndex.advanced(by: -1), newBlockTime: blockTime, params: consensusParameters)

        var nonce = 0
        var block: TransactionBlock
        repeat {
            block = TransactionBlock(
                header: .init(
                    version: 0x20000000,
                    previous: previousBlockHash,
                    merkleRoot: merkleRoot,
                    time: blockTime,
                    target: nextTarget,
                    nonce: nonce
                ),
                transactions: blockTransactions)
            nonce += 1
        } while Arithmetic256.compare(Arithmetic256.fromData(block.hash), to: target) > 0

        blockchain.append(block)
        mempool = .init()
    }

    func getNextWorkRequired(forHeight heightLast: Int, newBlockTime: Date, params: ConsensusParameters) -> Int {
        precondition(heightLast >= 0)
        let lastBlock = blockchain[heightLast]
        let powLimitUInt256 = Arithmetic256.fromData(Data(params.powLimit.reversed()))
        let proofOfWorkLimit = Arithmetic256.toCompact(powLimitUInt256)

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

    func calculateNextWorkRequired(lastBlock: TransactionBlock, firstBlockTime: Date, params: ConsensusParameters) -> Int {
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
        let powLimitUInt256 = Arithmetic256.fromData(Data(params.powLimit.reversed()))

        var new = Arithmetic256.fromCompact(lastBlock.header.target)
        precondition(!Arithmetic256.isZero(new))
        new = Arithmetic256.multiply(new, UInt32(actualTimespan))
        new = Arithmetic256.divide(new, Arithmetic256.fromUInt64(UInt64(params.powTargetTimespan)))

        if Arithmetic256.compare(new, to: powLimitUInt256) > 0 {
            new = powLimitUInt256
        }

        return Arithmetic256.toCompact(new)
    }
}
