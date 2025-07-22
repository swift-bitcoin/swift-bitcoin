import BitcoinBase

public enum TransactionValidationError: Error {
    case transactionCheckError(Transaction.ValidationError)
    case nonFinalTransaction
    case scriptError
}
