import Foundation

/// A message containing a block.
public struct BlockMessage: Equatable {

    // MARK: - Initializers

    public init(block: TransactionBlock, network: BlockNetwork = .main) {
        self.block = block
        self.network = network
    }

    // MARK: - Instance Properties

    public let block: TransactionBlock
    public let network: BlockNetwork

}
