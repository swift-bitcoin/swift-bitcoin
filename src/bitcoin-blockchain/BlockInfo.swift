import Foundation

/// Additional information about a block in the blockchain.
public struct BlockInfo: Sendable {
    public init(height: Int, confirmations: Int, chainwork: Data) {
        self.height = height
        self.confirmations = confirmations
        self.chainwork = chainwork
    }
    
    public let height: Int
    public let confirmations: Int
    public let chainwork: Data
}
