import BitcoinBase
import Foundation

/// Additional information about a block in the blockchain.
public struct BlockInfo: Sendable {
    public init(
        next: BlockHash?, height: Int, confirmations: Int, status: ValidationStatus, difficulty: Double,
        chainwork: String, medianTime: Date
    ) {
        self.next = next
        self.height = height
        self.confirmations = confirmations
        self.status = status
        self.difficulty = difficulty
        self.chainwork = chainwork
        self.medianTime = medianTime
    }

    public let next: BlockHash?
    public let height: Int
    public let confirmations: Int
    public let status: ValidationStatus
    public let difficulty: Double
    public let chainwork: String
    public let medianTime: Date
}
