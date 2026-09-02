import Foundation
import BitcoinCrypto
import BitcoinBase

public extension Block {
    static func genesis(_ params: ConsensusParams) -> Self {
        let genesisTx = Transaction.genesis(params.genesisTxParams)
        let target = params.genesisBlockTarget
        let genesisBlock = Block(
            version: 1,
            previous: Block.nullParent,
            merkleRoot: calculateMerkleRoot([genesisTx]),
            time: Date(timeIntervalSince1970: TimeInterval(params.genesisBlockTime)),
            target: target,
            nonce: params.genesisBlockNonce,
            txs: [genesisTx])
        return genesisBlock
    }

    var work: DifficultyTarget { .getWork(target) }
}

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
extension Block {

    func shortTransactionIDParams(nonce: UInt64) -> (first: UInt64, second: UInt64) {
        // single-SHA256 hashing the block header with the nonce appended (in little-endian)
        let headerData = Data(capacity: Block.headerSize + MemoryLayout<UInt64>.size) { out in
            out.append(contentsOf: data(binaryFormat: .headerOnly))
            out.append(nonce, as: UInt64.self, .littleEndian)
        }
        let headerHash = Data(SHA256.hash(data: headerData))

        // Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
        let first = headerHash.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        let second = headerHash.dropFirst(MemoryLayout.size(ofValue: first)).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        return (first, second)
    }

    public func shortTransactionIDs(nonce: UInt64, dropIndices: [Int]) -> [UInt64] {
        let (first, second) = shortTransactionIDParams(nonce: nonce)
        let txs = txs.enumerated().compactMap { i, tx in
            dropIndices.contains(i) ? nil :tx
        }
        return txs.map { tx in tx.shortID(nonce: nonce, first: first, second: second) }
    }
}
