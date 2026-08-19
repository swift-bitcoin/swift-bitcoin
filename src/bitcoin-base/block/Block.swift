import Foundation
import BitcoinCrypto

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
    public var version: Int
    public var previous: Block.ID
    public var merkleRoot: Data
    public var time: Date

    /// Difficulty bits.
    public var target: Int

    public var nonce: Int

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
        dataSize(encoding: .noWitness) * 3 + dataSize
    }

    // MARK: - Instance Methods

    /// Repopulates the Merkle root in ``merkleRoot`` based on current transactions in ``txs``.
    public mutating func recalculateMerkleRoot() {
        merkleRoot = calculateWitnessMerkleRoot(txs)
    }

    // MARK: - Type Properties

    public static let idLength = Hash256.Digest.byteCount
    public static let nullParent = Block.ID(count: 32)

    /// BIP9 version bits prefix `0b001…`
    public static let versionBitsTopBits = 0x20000000
}

package extension Block {
    /// Minimum size of data in bytes.
    static let minSize = headerSize + 1

    /// Size of header data in bytes.
    static let headerSize = 80
}

extension Block: CustomBinaryCodable {

    public enum Encoding: Equatable, Sendable {
        case headerOnly
        case noWitness

        /// For signet challenge verification. Use only with encoder, not decoder.
        ///
        /// BIP325
        case signet

        /// For block and undo file storage.
        case file(magicBytes: Int)
    }

    public init(from decoder: inout BinaryDecoder, encoding: Encoding?) throws {
        switch encoding {
        case nil, .headerOnly, .noWitness:
            let version = Int(try decoder.decode() as Int32)
            let previous = try decoder.decode(Block.idLength)
            let merkleRoot = try decoder.decode(Block.idLength)
            let time = Date(timeIntervalSince1970: TimeInterval(try decoder.decode() as UInt32))
            let target = Int(try decoder.decode() as UInt32)
            let nonce = Int(try decoder.decode() as UInt32)
            let txs: [Transaction] = if encoding == .headerOnly {
                []
            } else {
                try decoder.decode(encoding: encoding == .noWitness ? .noWitness : nil)
            }
            self.init(version: version, previous: previous, merkleRoot: merkleRoot, time: time, target: target, nonce: nonce, txs: txs)
        case .signet: fatalError("Signet encoding is for use with encoder only.")
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
        case nil, .headerOnly, .noWitness:
            encoder.encode(Int32(version))
            encoder.encode(previous)
            encoder.encode(merkleRoot)
            encoder.encode(UInt32(time.timeIntervalSince1970))
            encoder.encode(UInt32(target))
            encoder.encode(UInt32(nonce))
            if encoding != .headerOnly {
                encoder.encode(txs, encoding: encoding == .noWitness ? .noWitness : nil)
            }
        case .signet:
            encoder.encode(Int32(version))
            encoder.encode(previous)
            encoder.encode(merkleRoot)
            encoder.encode(UInt32(time.timeIntervalSince1970))
        case .file(let magicBytes):
            encoder.encode(UInt32(magicBytes))
            encoder.encode(UInt32(dataSize))
            encode(to: &encoder)
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Encoding?) {
        switch encoding {
        case nil, .headerOnly, .noWitness:
            counter.count(Int32(version))
            counter.count(previous)
            counter.count(merkleRoot)
            counter.count(UInt32(time.timeIntervalSince1970))
            counter.count(UInt32(target))
            counter.count(UInt32(nonce))
            if encoding != .headerOnly {
                counter.count(txs, encoding: encoding == .noWitness ? .noWitness : nil)
            }
        case .signet:
            counter.count(Int32(version))
            counter.count(previous)
            counter.count(merkleRoot)
            counter.count(UInt32(time.timeIntervalSince1970))
        case .file(_):
            counter.count(UInt32.self)
            counter.count(UInt32.self)
            encodingSize(&counter)
        }
    }
}
