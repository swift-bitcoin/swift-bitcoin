import Foundation
import BitcoinCrypto

/// A block of transactions.
public struct TransactionBlock: Equatable {

    // MARK: - Initializers

    public init(header: BlockHeader, transactions: [BitcoinTransaction]) {
        self.header = header
        self.transactions = transactions
    }

    // MARK: - Instance Properties

    public let header: BlockHeader
    public let transactions: [BitcoinTransaction]

    // MARK: - Computed Properties

    public var hash: Data {
        hash256(header.data)
    }

    public var identifier: Data {
        Data(hash.reversed())
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods

    // No type methods yet.
}
