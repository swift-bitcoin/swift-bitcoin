public enum PartiallySignedTxError: Error {
    /// External errors / referenced in test vectors
    case invalidPrefix, invalidOrMissingGlobalMap, missingInputMaps, invalidInputMap, missingOutputMaps, unlockScriptNonEmpty, witnessNonEmpty, duplicateKey, invalidInputKeyData
    case unsupportedVersion, missingVersion, invalidVersionEncoding, invalidVersion, invalidUnsignedVersionKey, missingUnsignedTransaction, invalidUnsignedTransaction, invalidUnsignedTransactionKey, invalidProprietaryKey, invalidInputPreviousTransaction, invalidInputPreviousOutput, invalidInputRedeemScript, invalidInputWitnessScript, missingPreviousOutput, missingInputRedeemScript, nonSegwitPreviousOutput, invalidOutputRedeemScript, invalidOutputWitnessScript
}
