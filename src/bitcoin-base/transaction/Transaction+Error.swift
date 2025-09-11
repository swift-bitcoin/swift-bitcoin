import Foundation

extension Transaction {

    /// An error while checking a bitcoin transaction.
    public enum ValidationError: Error {
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
             feeOutOfRange
    }

    public enum DecodingError: Error {
        case witnessEncoded
    }
}
