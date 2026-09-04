import Foundation
import BinaryParsing
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

extension BlockRef: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        header = try .init(parsing: &input)
        height = try Int(UInt32(parsingLittleEndian: &input)) // TODO: Verify conversion to UInt32
        chainwork = try .init(parsing: &input)
        chainTxCount = try Int(UInt32(parsingLittleEndian: &input))
        let statusRaw = try UInt8(parsing: &input)
        guard let status = ValidationStatus(rawValue: statusRaw) else {
            throw BinaryDecodingError.invalidEnumCase
        }
        self.status = status
        let locator: BlockStorageLocator = try .init(parsing: &input)
        self.locator = locator == .placeholder ? nil : locator
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(header)
        counter.count(UInt32.self)
        counter.count(chainwork)
        counter.count(UInt32.self)
        counter.count(status)
        counter.count(BlockStorageLocator.placeholder)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try header.encode(into: &out)
        out.append(UInt32(height), as: UInt32.self, .littleEndian)
        try chainwork.encode(into: &out)
        out.append(UInt32(chainTxCount), as: UInt32.self, .littleEndian)
        out.append(status.rawValue)
        if let locator {
            try locator.encode(into: &out)
        } else {
            try BlockStorageLocator.placeholder.encode(into: &out)
        }
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

extension ValidationStatus: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        guard let maybeSelf = Self(rawValue: try .init(parsing: &input)) else {
            throw BinaryDecodingError.invalidEnumCase
        }
        self = maybeSelf
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt8.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(rawValue)
    }
}
