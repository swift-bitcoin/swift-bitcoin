import BitcoinBase

/// Issue checking transaction in the context of the blockchain or verifying its scripts.
public enum TransactionValidationError: Error {

    /// Transaction sanity check failure.
    case transactionCheckError(Transaction.ValidationError)

    /// Transaction is non-final.
    case nonFinalTransaction

    /// Script verification error.
    case scriptError
}
