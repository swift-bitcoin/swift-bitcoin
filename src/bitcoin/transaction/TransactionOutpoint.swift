import Foundation

/// A reference to a particular ``Output`` of a particular ``Transaction``.
public struct TransactionOutpoint: Equatable, Hashable {

    init(transaction: Data, output: Int) {
        precondition(transaction.count == BitcoinTransaction.identifierSize)
        self.transactionIdentifier = transaction
        self.outputIndex = output
    }

    // The identifier for the transaction containing the referenced output.
    public let transactionIdentifier: Data

    /// The index of an output in the referenced transaction.
    public let outputIndex: Int

    public static let coinbase = Self(
        transaction: .init(count: BitcoinTransaction.identifierSize),
        output: 0xffffffff
    )
}
