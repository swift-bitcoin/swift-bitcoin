import Foundation
import BitcoinCrypto
import BitcoinBase

/// A block of transactions. It may be interpreted as a just a block header when body of transactions is empty. It may also include additional contextual information such as the block's height within the blockchain.
public struct Block: Equatable, Sendable {

    public typealias ID = Data

    // MARK: - Initializers

    public init(version: Int = Self.versionBitsTopBits, previous: Data, merkleRoot: Data, time: Date = .now, target: Int, nonce: Int = 0, txs: [Transaction] = []) {
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
    public let previous: Block.ID
    public let merkleRoot: Data
    public let time: Date

    /// Difficulty bits.
    public let target: Int

    public let nonce: Int

    public var txs: [Transaction]

    // MARK: - Computed Properties

    public var id: Block.ID {
        Data(Hash256.hash(data: data(encoding: .headerOnly)))
    }

    public var idHex: String { id.reversed().hex }

    /// Returns a copy of self without the transactions – i.e. header only.
    public var header: Self {
        var header = self
        header.txs = []
        return header
    }

    public var weight: Int {
        dataSize(encoding: .nonWitness) * 3 + dataSize
    }

    var work: DifficultyTarget { .getWork(target) }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    public static let idLength = Hash256.Digest.byteCount
    public static let nullParent = Block.ID(count: 32)

    /// BIP9 version bits prefix `0b001…`
    public static let versionBitsTopBits = 0x20000000

    // MARK: - Type Methods

    public static func genesis(_ params: ConsensusParams) -> Self {
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
}

package extension Block {
    /// Minimum size of data in bytes.
    static let minSize = headerSize + 1

    /// Size of header data in bytes.
    static let headerSize = 80
}

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
package extension Block {

    func makeShortIDParams(nonce: UInt64) -> (first: UInt64, second: UInt64) {
        // single-SHA256 hashing the block header with the nonce appended (in little-endian)
        var encoder = BinaryEncoder(size: Block.headerSize + MemoryLayout<UInt64>.size)
        encoder.encode(data(encoding: .headerOnly))
        encoder.encode(nonce)
        let headerData = encoder.data
        let headerHash = Data(SHA256.hash(data: headerData))

        // Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
        let first = headerHash.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        let second = headerHash.dropFirst(MemoryLayout.size(ofValue: first)).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        return (first, second)
    }

    func makeShortTxIDs(nonce: UInt64, dropIndices: [Int]) -> [UInt64] {
        let (first, second) = makeShortIDParams(nonce: nonce)
        let txs = txs.enumerated().compactMap { i, tx in
            dropIndices.contains(i) ? nil :tx
        }
        return txs.map { tx in tx.makeShortTxID(nonce: nonce, first: first, second: second) }
    }
}

package extension Transaction {
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

extension Block: CustomBinaryCodable {

    public enum Encoding: Equatable, Sendable {
        case headerOnly, nonWitness, file(magicBytes: Int)
    }

    public init(from decoder: inout BinaryDecoder, encoding: Encoding?) throws {
        switch encoding {
        case nil, .headerOnly, .nonWitness:
            let version = Int(try decoder.decode() as Int32)
            let previous = try decoder.decode(Block.idLength)
            let merkleRoot = try decoder.decode(Block.idLength)
            let time = Date(timeIntervalSince1970: TimeInterval(try decoder.decode() as UInt32))
            let target = Int(try decoder.decode() as UInt32)
            let nonce = Int(try decoder.decode() as UInt32)
            let txs: [Transaction] = if encoding == .headerOnly {
                []
            } else {
                try decoder.decode(encoding: encoding == .nonWitness ? .nonWitness : nil)
            }
            self.init(version: version, previous: previous, merkleRoot: merkleRoot, time: time, target: target, nonce: nonce, txs: txs)
        case .file(let magicBytes):
            let magic = Int(try decoder.decode() as UInt32)
            guard magic == magicBytes else {
                throw BinaryDecodingError.limitExceeded
            } // TODO: Replace error for something appropriate
            let length = Int(try decoder.decode() as UInt32)
            decoder.setLimit(length)
            try self.init(from: &decoder)
            decoder.resetLimit()
        }
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Encoding?) {
        switch encoding {
        case nil, .headerOnly, .nonWitness:
            encoder.encode(Int32(version))
            encoder.encode(previous)
            encoder.encode(merkleRoot)
            encoder.encode(UInt32(time.timeIntervalSince1970))
            encoder.encode(UInt32(target))
            encoder.encode(UInt32(nonce))
            if encoding != .headerOnly {
                encoder.encode(txs, encoding: encoding == .nonWitness ? .nonWitness : nil)
            }
        case .file(let magicBytes):
            encoder.encode(UInt32(magicBytes))
            encoder.encode(UInt32(dataSize))
            encode(to: &encoder)
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Encoding?) {
        switch encoding {
        case nil, .headerOnly, .nonWitness:
            counter.count(Int32(version))
            counter.count(previous)
            counter.count(merkleRoot)
            counter.count(UInt32(time.timeIntervalSince1970))
            counter.count(UInt32(target))
            counter.count(UInt32(nonce))
            if encoding != .headerOnly {
                counter.count(txs, encoding: encoding == .nonWitness ? .nonWitness : nil)
            }
        case .file(_):
            counter.count(UInt32.self)
            counter.count(UInt32.self)
            encodingSize(&counter)
        }
    }
}
