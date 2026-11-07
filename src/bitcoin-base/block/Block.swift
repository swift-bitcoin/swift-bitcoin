import BinaryParsing
import BitcoinCrypto
import Foundation

/// A block of transactions. It may be interpreted as a just a block header when body of transactions is empty. It may also include additional contextual information such as the block's height within the blockchain.
public struct Block: Equatable, Sendable {
    public typealias ID = Data

    // MARK: - Initializers

    public init(
        version: Int = Self.versionBitsTopBits, previous: BlockHash, merkleRoot: MerkleRoot, time: Date = .now,
        target: Int, nonce: Int = 0, txs: [Transaction] = []
    ) {
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
    public var previous: BlockHash
    public var merkleRoot: MerkleRoot
    public var time: Date

    /// Difficulty bits.
    public var target: Int

    public var nonce: Int

    public var txs: [Transaction]

    // MARK: - Computed Properties

    public var id: BlockHash {
        BlockHash(Hash256(SHA256d.hash(data: data(binaryFormat: .headerOnly))))
    }

    public var idHex: String { id.displayHex }

    /// Returns a copy of self without the transactions – i.e. header only.
    public var header: Self {
        var header = self
        header.txs = []
        return header
    }

    public var weight: Int {
        binarySize(format: .noWitness) * 3 + binarySize
    }

    // MARK: - Instance Methods

    /// Repopulates the Merkle root in ``merkleRoot`` based on current transactions in ``txs``.
    public mutating func recalculateMerkleRoot() {
        merkleRoot = calculateMerkleRoot(txs)
    }

    // MARK: - Type Properties

    /// BIP9 version bits prefix `0b001…`
    public static let versionBitsTopBits = 0x2000_0000
}

extension Block {
    /// Minimum size of data in bytes.
    package static let minSize = headerSize + 1

    /// Size of header data in bytes.
    package static let headerSize = 80
}

extension Block: BinaryCodable {
    public enum BinaryFormat: Equatable, Sendable {
        case headerOnly
        case noWitness

        /// For signet challenge verification. Use only with encoder, not decoder.
        ///
        /// BIP325
        case signet

        /// For block and undo file storage.
        case file(magicBytes: Int)
    }

    public init(parsing input: inout ParserSpan, format: BinaryFormat?) throws {
        switch format {
        case nil, .headerOnly, .noWitness:
            let version = Int(try Int32(parsingLittleEndian: &input))
            let previous = try BlockHash(parsing: &input)
            let merkleRoot = try MerkleRoot(parsing: &input)
            let time = Date(timeIntervalSince1970: TimeInterval(try UInt32(parsingLittleEndian: &input)))
            let target = Int(try UInt32(parsingLittleEndian: &input))
            let nonce = Int(try UInt32(parsingLittleEndian: &input))

            let txs: [Transaction] =
                if format == .headerOnly {
                    []
                } else {
                    try [Transaction](parsing: &input, format: format == .noWitness ? (nil, .noWitness) : nil)
                }
            self.init(
                version: version, previous: previous, merkleRoot: merkleRoot, time: time, target: target, nonce: nonce,
                txs: txs)
        case .signet: fatalError("Signet encoding is for use with encoder only.")
        case .file(let magicBytes):
            let magic = Int(try UInt32(parsingLittleEndian: &input))
            guard magic == magicBytes else {
                throw BinaryDecodingError.invalidMessageStart
            }
            let length = Int(try UInt32(parsingLittleEndian: &input))
            var trimmedInput = try input.sliceSpan(byteCount: length)
            try self.init(parsing: &trimmedInput)
            try input.seek(toAbsoluteOffset: trimmedInput.endPosition)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws {
        switch format {
        case nil, .headerOnly, .noWitness:
            out.append(Int32(version), as: Int32.self, .littleEndian)
            //out.append(contentsOf: previous)
            previous.encode(into: &out)
            //out.append(contentsOf: merkleRoot)
            merkleRoot.encode(into: &out)
            out.append(UInt32(time.timeIntervalSince1970), as: UInt32.self, .littleEndian)
            out.append(UInt32(target), as: UInt32.self, .littleEndian)
            out.append(UInt32(nonce), as: UInt32.self, .littleEndian)
            if format != .headerOnly {
                try txs.encode(into: &out, format: format == .noWitness ? (nil, .noWitness) : nil)
            }
        case .signet:
            out.append(Int32(version), as: Int32.self, .littleEndian)
            //out.append(contentsOf: previous)
            previous.encode(into: &out)
            //out.append(contentsOf: merkleRoot)
            merkleRoot.encode(into: &out)
            out.append(UInt32(time.timeIntervalSince1970), as: UInt32.self, .littleEndian)
        case .file(let magicBytes):
            out.append(UInt32(magicBytes), as: UInt32.self, .littleEndian)
            out.append(UInt32(binarySize), as: UInt32.self, .littleEndian)
            try encode(into: &out)
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        switch format {
        case nil, .headerOnly, .noWitness:
            counter.count(Int32.self)
            counter.countSize(Hash256.byteCount)
            counter.countSize(Hash256.byteCount)
            counter.count(UInt32.self)
            counter.count(UInt32.self)
            counter.count(UInt32.self)
            if format != .headerOnly {
                counter.count(txs, format: format == .noWitness ? (nil, .noWitness) : nil)
            }
        case .signet:
            counter.count(Int32.self)
            counter.countSize(Hash256.byteCount)
            counter.countSize(Hash256.byteCount)
            counter.count(UInt32.self)
        case .file(_):
            counter.count(UInt32.self)
            counter.count(UInt32.self)
            countBytes(into: &counter)
        }
    }
}
