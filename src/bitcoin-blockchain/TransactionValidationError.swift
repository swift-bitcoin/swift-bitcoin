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

    /// Transaction is non-final.
    case nonFinalTransaction

    /// Script verification error.
    case scriptError
}
