import Foundation

/// An error while executing a bitcoin script.
enum TransactionError: Error {
    case noInputs,
         noOutputs,
         oversized,
         negativeOutput,
         outputTooLarge,
         totalOutputsTooLarge,
         duplicateInput,
         coinbaseLengthOutOfRange,
         missingOutpoint,
         inputMissingOrSpent,
         prematureCoinbaseSpend,
         inputValuesOutOfRange,
         inputsValueBelowOutput,
         feeOutOfRange
}
