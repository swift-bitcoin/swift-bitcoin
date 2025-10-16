import Foundation

/// A summary of a chain tip – i.e. fork
public struct ChainTipSummary: Equatable, Sendable {

    // Mainly for testing
    package init(tip: Block.ID, height: Int, branchLength: Int, status: ValidationStatus) {
        self.tip = tip
        self.height = height
        self.branchLength = branchLength
        self.status = status
    }
    

    init(_ fork: ChainFork) {
        tip = fork.tip.header.id
        height = fork.tip.height
        branchLength = height - fork.start.height + 1
        status = fork.tip.status
    }

    public let tip: Block.ID
    public let height: Int
    public let branchLength: Int
    public let status: ValidationStatus
}
