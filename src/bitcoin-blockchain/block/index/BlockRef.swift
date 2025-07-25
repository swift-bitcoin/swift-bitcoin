import Foundation
import BitcoinCrypto

/// A block of transactions.
struct BlockRef: Equatable, Sendable {

    enum ValidationStatus: UInt8, Comparable {

        case header, merkle, full, stale

        static func < (lhs: BlockRef.ValidationStatus, rhs: BlockRef.ValidationStatus) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Initializers

    init(_ block: Block, height: Int, chainwork: DifficultyTarget, chainTxCount: Int, status: ValidationStatus = .header, locator: BlockStorageLocator? = nil) {
        self.header = block.header
        self.previous = block.previous
        self.height = height
        self.chainwork = chainwork
        self.chainTxCount = chainTxCount
        self.status = status
        self.locator = locator
    }

    // MARK: - Instance Properties

    public let header: Block
    public let previous: Block.ID
    public let height: Int
    public let chainwork: DifficultyTarget
    public let chainTxCount: Int
    public internal(set) var status: ValidationStatus
    public internal(set) var locator: BlockStorageLocator?

    // MARK: - Computed Properties

    /// Calculate the difficulty for a given block index.
    var difficulty: Double {
        DifficultyTarget.getDifficulty(header.target)
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods
}

extension BlockRef.ValidationStatus: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws {
        guard let maybeSelf = Self(rawValue: try decoder.decode()) else {
            throw BinaryDecodingError.limitExceeded // TODO: find better error
        }
        self = maybeSelf
    }
    
    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(rawValue)
    }
    
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(UInt8.self)
    }
    
}

extension BlockRef: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws {
        header = try decoder.decode()
        previous = try decoder.decode(Block.idLength)
        height = try decoder.decode()
        chainwork = try decoder.decode()
        chainTxCount = try decoder.decode()
        status = try decoder.decode()
        let hasLocator: Bool = try decoder.decode()
        if hasLocator {
            locator = try decoder.decode()
        }
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(header)
        encoder.encode(previous)
        encoder.encode(height)
        encoder.encode(chainwork)
        encoder.encode(chainTxCount)
        encoder.encode(status)
        if let locator {
            encoder.encode(true)
            encoder.encode(locator)
        } else {
            encoder.encode(false)
        }
    }
    
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(header)
        counter.count(previous)
        counter.count(height)
        counter.count(chainwork)
        counter.count(chainTxCount)
        counter.count(status)
        counter.count(Bool.self)
        if let locator {
            counter.count(locator)
        }
    }
}
