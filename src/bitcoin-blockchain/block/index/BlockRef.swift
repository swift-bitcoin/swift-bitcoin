import Foundation
import BitcoinCrypto

/// A block of transactions.
struct BlockRef: Equatable, Sendable {

    // MARK: - Initializers

    init(_ block: Block, height: Int, chainwork: DifficultyTarget, chainTxCount: Int, status: ValidationStatus = .header, locator: BlockStorageLocator? = nil) {
        self.header = block.header
        self.height = height
        self.chainwork = chainwork
        self.chainTxCount = chainTxCount
        self.status = status
        self.locator = locator
    }

    // MARK: - Instance Properties

    public let header: Block
    public let height: Int
    public let chainwork: DifficultyTarget
    public internal(set) var chainTxCount: Int
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

extension ValidationStatus: BinaryCodable {
    public init(from decoder: inout BinaryDecoder) throws {
        guard let maybeSelf = Self(rawValue: try decoder.decode()) else {
            throw BinaryDecodingError.limitExceeded // TODO: find better error
        }
        self = maybeSelf
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(rawValue)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(UInt8.self)
    }

}

extension BlockRef: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws {
        header = try decoder.decode()
        height = try decoder.decode()
        chainwork = try decoder.decode()
        chainTxCount = try decoder.decode()
        status = try decoder.decode()
        let locator: BlockStorageLocator = try decoder.decode()
        self.locator = locator == .placeholder ? nil : locator
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(header)
        encoder.encode(height)
        encoder.encode(chainwork)
        encoder.encode(chainTxCount)
        encoder.encode(status)
        if let locator {
            encoder.encode(locator)
        } else {
            encoder.encode(BlockStorageLocator.placeholder)
        }
    }

    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(header)
        counter.count(height)
        counter.count(chainwork)
        counter.count(chainTxCount)
        counter.count(status)
        counter.count(BlockStorageLocator.placeholder)
    }
}

public enum ValidationStatus: UInt8, CustomStringConvertible, Sendable {
    case header, merkle, active, invalid, stale

    var score: Int {
        switch self {
        case .header: 0
        case .merkle: 1
        case .active: 3
        case .invalid: -1
        case .stale: 2
        }
    }

    public var description: String {
        switch self {
        case .header: "header"
        case .merkle: "merkle"
        case .active: "active"
        case .invalid: "invalid"
        case .stale: "stale"
        }
    }
}
