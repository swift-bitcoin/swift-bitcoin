import BitcoinBase

/// Issue checking transaction in the context of the blockchain or verifying its scripts.
public enum TransactionValidationError: Error {

    /// Attempt to add a coinbase transaction to the mempool
    case coinbaseTransaction

    case nonStandardTransaction(PolicyViolation)
    case nonStandardWitness(PolicyViolation)
    case nonStandardPrevouts(PolicyViolation)
    case smallTransactionSize

    /// Transaction sanity check failure.
    case transactionCheckError(Transaction.ValidationError)

    case transactionAlreadyKnown
    case inputsMissingOrSpent

    /// Transaction is non-final.
    case nonFinalTransaction

    case transactionAlreadyInMempool
    case transactionSameNonWitnessDataInMempool

    /// Script verification error.
    case scriptError

    case tooManySigops
    case feeTooLow

    // Contextual Block Check
    case badHeightInCoinbase, badBlockWeight

    case badWitnessNonceSize, badWitnessMerkleMatch, unexpectedWitness
}
