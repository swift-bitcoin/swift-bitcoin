import Foundation

/// A block of transactions.
struct BlockRef: Equatable, Sendable {

    enum ValidationStatus {
        case header, merkle, full
    }

    // MARK: - Initializers

    public init(_ block: TxBlock, height: Int, locator: BlockStorage.Locator, chainwork: DifficultyTarget, status: ValidationStatus = .header) {
        self.blockID = block.id
        self.previous = block.previous
        self.time = block.time
        self.target = block.target
        self.height = height
        self.locator = locator
        self.chainwork = chainwork
        self.status = status
    }

    // MARK: - Instance Properties

    public let blockID: BlockID
    public let previous: BlockID
    public let time: Date
    public let target: Int
    public let height: Int
    public let locator: BlockStorage.Locator
    public let chainwork: DifficultyTarget
    public internal(set) var status: ValidationStatus

    // MARK: - Computed Properties

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods
}
