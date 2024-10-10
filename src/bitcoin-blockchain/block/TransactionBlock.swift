import Foundation
import BitcoinCrypto
import BitcoinBase

/// A block of transactions.
public struct TransactionBlock: Equatable, Sendable {

    // MARK: - Initializers

    public init(header: BlockHeader, transactions: [BitcoinTransaction] = []) {
        self.header = header
        self.transactions = transactions
    }

    // MARK: - Instance Properties

    public let header: BlockHeader
    public let transactions: [BitcoinTransaction]

    // MARK: - Computed Properties

    public var hash: Data {
        header.hash
    }

    public var identifier: Data {
        header.identifier
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods

    static func makeGenesisBlock(consensusParams: ConsensusParams) -> Self {
        let genesisTx = BitcoinTransaction.makeGenesisTransaction(blockSubsidy: consensusParams.blockSubsidy)
        let genesisBlock = TransactionBlock(
            header: .init(
                version: 1,
                previous: Data(count: 32),
                merkleRoot: genesisTx.identifier,
                time: Date(timeIntervalSince1970: TimeInterval(consensusParams.genesisBlockTime)),
                target: consensusParams.genesisBlockTarget,
                nonce: consensusParams.genesisBlockNonce
            ),
            transactions: [genesisTx])
        return genesisBlock
    }
}

extension TransactionBlock {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    public init?(_ data: Data) {
        // Check we at least have enough data for block header + transactions
        guard data.count > 80 else {
            return nil
        }
        var data = data

        // Header
        guard let header = BlockHeader(data) else {
            return nil
        }
        data = data.dropFirst(BlockHeader.size)
        self.header = header

        guard let transactionCount = data.varInt, transactionCount <= Int.max else {
            return nil
        }
        data = data.dropFirst(transactionCount.varIntSize)

        var transactions = [BitcoinTransaction]()
        for _ in 0 ..< transactionCount {
            guard let transaction = BitcoinTransaction(data) else {
                return nil
            }
            transactions.append(transaction)
        }
        self.transactions = transactions
    }

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(header.data)
        offset = ret.addData(Data(varInt: .init(transactions.count)), at: offset)
        ret.addData(Data(transactions.map(\.data).joined()), at: offset)
        return ret
    }

    /// Size of data in bytes.
    var size: Int {
        let transactionsSize = transactions.reduce(0) { $0 + $1.size }
        return BlockHeader.size +
               UInt64(transactions.count).varIntSize +
               transactionsSize // Transactions
    }
}

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
extension TransactionBlock {

    /// Short transaction IDs are used to represent a transaction without sending a full 256-bit hash. They are calculated by:
    ///   1. single-SHA256 hashing the block header with the nonce appended (in little-endian)
    ///   2. Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
    ///   3. Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
    func makeShortTransactionIdentifier(for transactionIndex: Int, nonce: UInt64) -> Int {

        // single-SHA256 hashing the block header with the nonce appended (in little-endian)
        let headerData = header.data + Data(value: nonce)
        let headerHash = Data(SHA256.hash(data: headerData))

        // Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
        let firstInt = headerHash.withUnsafeBytes { $0.load(as: UInt64.self) }
        let secondInt = headerHash.dropFirst(MemoryLayout.size(ofValue: firstInt)).withUnsafeBytes { $0.load(as: UInt64.self) }
        var sipHasher = SipHash(k0: firstInt, k1: secondInt)

        let transactionID = transactions[transactionIndex].witnessIdentifier
        transactionID.withUnsafeBytes { sipHasher.update(bufferPointer: $0) }
        let sipHash = sipHasher.finalize().value

        // Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
        return Int((sipHash << 16) >> 16)
    }
}
