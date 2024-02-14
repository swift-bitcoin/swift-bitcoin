import Foundation

/// A reference to a specific ``TransactionOutput`` of a particular ``BitcoinTransaction`` which is stored in a ``TransactionInput``.
public struct TransactionOutpoint: Equatable, Hashable {
    
    /// Creates a reference to an output of a previous transaction.
    /// - Parameters:
    ///   - transaction: The identifier for the previous transaction being referenced.
    ///   - output: The index within the previous transaction corresponding to the desired output.
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
