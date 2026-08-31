import Foundation
import BitcoinCrypto
import BitcoinBase

/// A block of transactions.
public struct BlockRef: Equatable, Hashable, Sendable {

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
    var locator: BlockStorageLocator?

    var skip: Block.ID? = nil

    // MARK: - Computed Properties

    /// Calculate the difficulty for a given block index.
    var difficulty: Double {
        DifficultyTarget.getDifficulty(header.target)
    }

    // MARK: - Instance Methods

    public func hash(into hasher: inout Hasher) {
        hasher.combine(header.id)
    }

    // MARK: - Type Properties

    // MARK: - Type Methods

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.header == rhs.header &&
        lhs.height == rhs.height &&
        lhs.chainwork == rhs.chainwork &&
        lhs.chainTxCount == rhs.chainTxCount &&
        lhs.status == rhs.status &&
        lhs.locator == rhs.locator
    }
}

extension ValidationStatus: BinaryCodable {
    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        guard let maybeSelf = Self(rawValue: try decoder.decode()) else {
            throw BinaryDecodingError.limitExceeded // TODO: find better error
        }
        self = maybeSelf
    }

    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(rawValue)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt8.self)
    }

}

extension BlockRef: BinaryCodable {
    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        header = try decoder.decode()
        height = try decoder.decode()
        chainwork = try decoder.decode()
        chainTxCount = try decoder.decode()
        status = try decoder.decode()
        let locator: BlockStorageLocator = try decoder.decode()
        self.locator = locator == .placeholder ? nil : locator
    }

    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
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

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(header)
        counter.count(height)
        counter.count(chainwork)
        counter.count(chainTxCount)
        counter.count(status)
        counter.count(BlockStorageLocator.placeholder)
    }
}

public enum ValidationStatus: UInt8, CustomStringConvertible, Equatable, Hashable, Sendable {
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
