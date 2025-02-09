import Foundation
import BitcoinCrypto
import BitcoinBase

public typealias BlockID = Data

/// A block of transactions. It may be interpreted as a just a block header when body of transactions is empty. It may also include additional contextual information such as the block's height within the blockchain.
public struct TxBlock: Equatable, Sendable {

    // MARK: - Initializers

    public init(version: Int = 2, previous: Data, merkleRoot: Data, time: Date = .now, target: Int, nonce: Int = 0, txs: [BitcoinTx] = []) {
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
        Data(Hash256.hash(data: dataHeaderOnly))
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
        return header
    }

    var work: DifficultyTarget { .getWork(target) }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    public static let idLength = Hash256.Digest.byteCount
    public static let nullParent = BlockID(count: 32)

    // MARK: - Type Methods

    static func makeGenesisBlock(params: ConsensusParams) -> Self {
        let genesisTx = BitcoinTx.makeGenesisTx(blockSubsidy: params.blockSubsidy)
        let target = params.genesisBlockTarget
        let genesisBlock = TxBlock(
            version: 1,
            previous: TxBlock.nullParent,
            merkleRoot: genesisTx.id,
            time: Date(timeIntervalSince1970: TimeInterval(params.genesisBlockTime)),
            target: target,
            nonce: params.genesisBlockNonce,
            txs: [genesisTx])
        return genesisBlock
    }
}

extension TxBlock: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        try self.init(fromHeaderOnly: &decoder)
        txs = try decoder.decode()
    }

    public init(fromHeaderOnly decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        version = Int(try decoder.decode() as Int32)
        previous = try decoder.decode(TxBlock.idLength, byteSwapped: true)
        merkleRoot = try decoder.decode(TxBlock.idLength, byteSwapped: true)
        time = Date(timeIntervalSince1970: TimeInterval(try decoder.decode() as UInt32))
        target = Int(try decoder.decode() as UInt32)
        nonce = Int(try decoder.decode() as UInt32)
        txs = []
    }

    public init(dataHeaderOnly: Data) throws {
        var decoder = BinaryDecoder(dataHeaderOnly)
        try self.init(fromHeaderOnly: &decoder)
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encodeHeaderOnly(to: &encoder)
        encoder.encode(txs)
    }

    public func encodeHeaderOnly(to encoder: inout BinaryEncoder) {
        encoder.encode(Int32(version))
        encoder.encode(previous, byteSwapped: true)
        encoder.encode(merkleRoot, byteSwapped: true)
        encoder.encode(UInt32(time.timeIntervalSince1970))
        encoder.encode(UInt32(target))
        encoder.encode(UInt32(nonce))
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        encodingSizeHeaderOnly(&counter)
        counter.count(txs)
    }

    public func encodingSizeHeaderOnly(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(Int32(version))
        counter.count(previous)
        counter.count(merkleRoot)
        counter.count(UInt32(time.timeIntervalSince1970))
        counter.count(UInt32(target))
        counter.count(UInt32(nonce))
    }

    public var dataHeaderOnly: Data {
        var encoder = BinaryEncoder(size: sizeHeaderOnly)
        encodeHeaderOnly(to: &encoder)
        return encoder.data
    }

    public var sizeHeaderOnly: Int {
        var counter = BinaryEncodingSizeCounter()
        self.encodingSizeHeaderOnly(&counter)
        return counter.size
    }
}

package extension TxBlock {
    /// Minimum size of data in bytes.
    static let minSize = headerSize + 1

    /// Size of header data in bytes.
    static let headerSize = 80
}

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
package extension TxBlock {

    func makeShortIDParams(nonce: UInt64) -> (first: UInt64, second: UInt64) {
        // single-SHA256 hashing the block header with the nonce appended (in little-endian)
        var encoder = BinaryEncoder(size: TxBlock.headerSize + MemoryLayout<UInt64>.size)
        encoder.encode(dataHeaderOnly)
        encoder.encode(nonce)
        let headerData = encoder.data
        let headerHash = Data(SHA256.hash(data: headerData))

        // Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
        let first = headerHash.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        let second = headerHash.dropFirst(MemoryLayout.size(ofValue: first)).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
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

extension TxBlock: CustomBinaryCodable {

    public enum Encoding { case file(magicBytes: Int) }

    public init(from decoder: inout BinaryDecoder, encoding: Encoding) throws(BinaryDecodingError) {
        switch encoding {
        case .file(let magicBytes):
            let magic = Int(try decoder.decode() as UInt32)
            guard magic == magicBytes else { throw BinaryDecodingError.limitExceeded } // TODO: Replace error for something appropriate
            let length = Int(try decoder.decode() as UInt32)
            decoder.setLimit(length)
            try self.init(from: &decoder)
            decoder.resetLimit()
        }
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Encoding) {
        switch encoding {
        case .file(let magicBytes):
            encoder.encode(UInt32(magicBytes))
            encoder.encode(UInt32(binarySize))
            encode(to: &encoder)
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Encoding) {
        counter.count(UInt32.self)
        counter.count(UInt32.self)
        encodingSize(&counter)
    }
}
