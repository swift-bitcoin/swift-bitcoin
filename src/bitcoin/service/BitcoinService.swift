import Foundation
import BitcoinCrypto

fileprivate let blockSubsidy = 50 * 100_000_000

public actor BitcoinService {

    public private(set) var blockchain = [TransactionBlock]()
    public private(set) var mempool = [BitcoinTransaction]()

    public init() { }

    public var genesisBlock: TransactionBlock {
        blockchain[0]
    }

    public func addTransaction(_ transaction: BitcoinTransaction) {
        mempool.append(transaction)
    }

    public var bits: Int {
        // TODO: Calculate difficulty based on blockchain history #135
        0x207fffff
    }

    public func createGenesisBlock(blockTime: Date = .now) {
        guard blockchain.isEmpty else { return }

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
                target: 0x207fffff,
                nonce: 2
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
        let target = Arithmetic256.makeCompact(compact: UInt32(bits), negative: &neg, overflow: &over)
        if Arithmetic256.isZero(target) || neg || over {
            preconditionFailure()
        }

        var nonce = 0
        var block: TransactionBlock
        repeat {
            block = TransactionBlock(
                header: .init(
                    version: 0x20000000,
                    previous: previousBlockHash,
                    merkleRoot: merkleRoot,
                    time: blockTime,
                    target: bits,
                    nonce: nonce
                ),
                transactions: blockTransactions)
            nonce += 1
        } while Arithmetic256.compare(Arithmetic256.dataToArith256(block.hash), to: target) > 0

        blockchain.append(block)
        mempool = .init()
    }
}
