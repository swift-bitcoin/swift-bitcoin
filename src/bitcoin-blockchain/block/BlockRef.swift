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

    init(_ block: TxBlock, height: Int, chainwork: DifficultyTarget, chainTxCount: Int, status: ValidationStatus = .header, locator: BlockStorage.Locator? = .none) {
        self.blockID = block.id
        self.previous = block.previous
        self.time = block.time
        self.target = block.target
        self.height = height
        self.chainwork = chainwork
        self.chainTxCount = chainTxCount
        self.status = status
        self.locator = locator
    }

    // MARK: - Instance Properties

    public let blockID: BlockID
    public let previous: BlockID
    public let time: Date
    public let target: Int
    public let height: Int
    public let chainwork: DifficultyTarget
    public let chainTxCount: Int
    public internal(set) var status: ValidationStatus
    public internal(set) var locator: BlockStorage.Locator?

    // MARK: - Computed Properties

    /// Calculate the difficulty for a given block index.
    var difficulty: Double {
        DifficultyTarget.getDifficulty(target)
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
        blockID = try decoder.decode(TxBlock.idLength)
        previous = try decoder.decode(TxBlock.idLength)
        time = try decoder.decode()
        target = try decoder.decode()
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
        encoder.encode(blockID)
        encoder.encode(previous)
        encoder.encode(time)
        encoder.encode(target)
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
        counter.count(blockID)
        counter.count(previous)
        counter.count(time)
        counter.count(target)
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
