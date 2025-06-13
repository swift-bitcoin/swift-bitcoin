import Foundation

/// Additional information about a block in the blockchain.
public struct BlockInfo: Sendable {
    public init(next: Block.ID?, height: Int, confirmations: Int, difficulty: Double, chainwork: Data, medianTime: Date) {
        self.next = next
        self.height = height
        self.confirmations = confirmations
        self.difficulty = difficulty
        self.chainwork = chainwork
        self.medianTime = medianTime
    }
    
    public let next: Block.ID?
    public let height: Int
    public let confirmations: Int
    public let difficulty: Double
    public let chainwork: Data
    public let medianTime: Date

}
