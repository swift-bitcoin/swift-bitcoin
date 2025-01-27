import Foundation
import BitcoinCrypto
import BitcoinBase

public typealias BlockID = Data

/// A block of transactions. It may be interpreted as a just a block header when body of transactions is empty. It may also include additional contextual information such as the block's height within the blockchain.
public struct TxBlock: Equatable, Sendable {

    // MARK: - Initializers

    public init(context: BlockContext? = .none, version: Int = 2, previous: Data, merkleRoot: Data, time: Date = .now, target: Int, nonce: Int = 0, txs: [BitcoinTx] = []) {
        self.context = context
        self.version = version
        self.previous = previous
        self.merkleRoot = merkleRoot

        // Reset date's nanoseconds
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        guard let time = calendar.date(bySetting: .nanosecond, value: 0, of: time) else { preconditionFailure() }
        self.time = time

        self.target = target
        self.nonce = nonce
        self.txs = txs
    }

    // MARK: - Instance Properties

    public var context: BlockContext?

    // Header
    public let version: Int
    public let previous: Data
    public let merkleRoot: Data
    public let time: Date

    /// Difficulty bits.
    public let target: Int

    public let nonce: Int

    public var txs: [BitcoinTx]

    // MARK: - Computed Properties

    public var hash: Data {
        Data(Hash256.hash(data: headerData))
    }

    public var id: BlockID {
        Data(hash.reversed())
    }

    public var idHex: String {
        id.hex
    }

    /// Returns a copy of self without the transactions – i.e. header only.
    public var header: Self {
        var header = self
        header.txs = []
        header.context = .none
        return header
    }

    var work: DifficultyTarget { .getWork(target) }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    public static let idLength = Hash256.Digest.byteCount

    // MARK: - Type Methods

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version &&
            lhs.previous == rhs.previous &&
            lhs.merkleRoot == rhs.merkleRoot &&
            lhs.time == rhs.time &&
            lhs.target == rhs.target &&
            lhs.nonce == rhs.nonce &&
            lhs.txs == rhs.txs
    }

    static func makeGenesisBlock(params: ConsensusParams) -> Self {
        let genesisTx = BitcoinTx.makeGenesisTx(blockSubsidy: params.blockSubsidy)
        let target = params.genesisBlockTarget
        let genesisBlock = TxBlock(
            context: .init(
                height: 0,
                chainwork: DifficultyTarget.getWork(target),
                status: .full
            ),
            version: 1,
            previous: Data(count: 32),
            merkleRoot: genesisTx.id,
            time: Date(timeIntervalSince1970: TimeInterval(params.genesisBlockTime)),
            target: target,
            nonce: params.genesisBlockNonce,
            txs: [genesisTx])
        return genesisBlock
    }
}

package extension TxBlock {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    init?(headerData data: Data) {
        // Check we at least have enough data for block header + empty transactions
        guard data.count >= Self.baseSize else {
            return nil
        }
        var data = data

        // Header
        version = Int(data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        data = data.dropFirst(MemoryLayout<Int32>.size)
        previous = Data(data.prefix(32).reversed())
        data = data.dropFirst(previous.count)
        merkleRoot = Data(data.prefix(32).reversed())
        data = data.dropFirst(merkleRoot.count)
        let seconds = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        time = Date(timeIntervalSince1970: TimeInterval(seconds))
        data = data.dropFirst(MemoryLayout.size(ofValue: seconds))
        target = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)
        nonce = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)

        self.txs = []
    }

    init?(_ data: Data) {
        var data = data
        self.init(headerData: data)
        data = data.dropFirst(Self.baseSize)

        // Check we at least have enough data for block header + empty transactions
        guard let txCount = data.varInt, txCount <= Int.max else {
            return nil
        }

        data = data.dropFirst(txCount.varIntSize)
        var txs = [BitcoinTx]()
        for _ in 0 ..< txCount {
            guard let tx = try? BitcoinTx(binaryData: data) else {
                return nil
            }
            txs.append(tx)
            data = data.dropFirst(tx.binarySize)
        }
        self.txs = txs
    }

    // MARK: - Computed Properties

    /// Header data
    var headerData: Data {
        var ret = Data(count: Self.baseSize)
        var offset = ret.addBytes(Int32(version))
        offset = ret.addData(previous.reversed(), at: offset)
        offset = ret.addData(merkleRoot.reversed(), at: offset)
        offset = ret.addBytes(UInt32(time.timeIntervalSince1970), at: offset)
        offset = ret.addBytes(UInt32(target), at: offset)
        offset = ret.addBytes(UInt32(nonce), at: offset)
        return ret
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(headerData)
        offset = ret.addData(Data(varInt: UInt64(txs.count)), at: offset)
        ret.addData(Data(txs.map(\.binaryData).joined()), at: offset)
        return ret
    }

    // MARK: - Type Properties

    /// Size of data in bytes.
    static let baseSize = 80

    /// Size of data in bytes.
    var size: Int {
        Self.baseSize + UInt64(txs.count).varIntSize + txs.reduce(0) { $0 + $1.binarySize }
    }
}

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
package extension TxBlock {

    func makeShortIDParams(nonce: UInt64) -> (first: UInt64, second: UInt64) {
        // single-SHA256 hashing the block header with the nonce appended (in little-endian)
        let headerData = headerData + Data(value: nonce)
        let headerHash = Data(SHA256.hash(data: headerData))

        // Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
        let first = headerHash.withUnsafeBytes { $0.load(as: UInt64.self) }
        let second = headerHash.dropFirst(MemoryLayout.size(ofValue: first)).withUnsafeBytes { $0.load(as: UInt64.self) }
        return (first, second)
    }

    func makeShortTxIDs(nonce: UInt64) -> [UInt64] {
        let (first, second) = makeShortIDParams(nonce: nonce)
        return txs.map { tx in tx.makeShortTxID(nonce: nonce, first: first, second: second) }
    }
}

package extension BitcoinTx {
    /// Short transaction IDs are used to represent a transaction without sending a full 256-bit hash. They are calculated by:
    ///   1. single-SHA256 hashing the block header with the nonce appended (in little-endian)
    ///   2. Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
    ///   3. Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
    func makeShortTxID(nonce: UInt64, first: UInt64, second: UInt64) -> UInt64 {
        var hasher = SipHash(k0: first, k1: second)
        let txID = witnessID
        txID.withUnsafeBytes { hasher.update(bufferPointer: $0) }
        let sipHash = hasher.finalize().value

        // Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
        return (sipHash << 16) >> 16
    }
}
