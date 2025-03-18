import Foundation

/// An error while checking a bitcoin transaction.
public enum TxError: Error {
    case missingInputs,
         missingOutputs,
         oversized,
         negativeOutput,
         outputTooLarge,
         totalOutputsTooLarge,
         duplicateInput,
         coinbaseLengthOutOfRange,
         missingOutpoint,
         inputMissingOrSpent,
         prematureCoinbaseSpend,
         inputValueOutOfRange,
         inputsValueBelowOutput,
         feeOutOfRange,
         futureLockTime
}

public enum TxDecodingError: Error {
    case witnessEncoded
}
