public enum PartiallySignedTxError: Error, Equatable {
    /// External errors / referenced in test vectors
    case invalidPrefix, invalidOrMissingGlobalMap, missingInputMaps, invalidInputMap, missingOutputMaps,
        unlockScriptNonEmpty, witnessNonEmpty, duplicateKey, invalidInputKeyData
    case nonEmptyInputKeyData(String)
    case nonEmptyOutputKeyData(String)
    case transactionIDMismatch
    case unsupportedVersion, missingVersion, invalidVersionEncoding, invalidVersion, invalidUnsignedVersionKey,
        missingUnsignedTransaction, invalidUnsignedTransaction, invalidUnsignedTransactionKey, invalidProprietaryKey,
        invalidInputPreviousTransaction, invalidInputPreviousOutput, invalidInputSighashType, invalidInputRedeemScript,
        invalidInputWitnessScript, missingPreviousOutput, missingWitnessPreviousOutput, missingInputRedeemScript,
        invalidInputFinalScriptSig, invalidInputFinalScriptWitness, nonSegwitPreviousOutput, invalidOutputRedeemScript,
        invalidOutputWitnessScript, invalidExtendedPublicKey, invalidPublicKeyDerivation, invalidPublicKey,
        invalidSignature, hashPreimageMismatch

    /// Signer checks
    case wrongRedeemScript, wrongWitnessScript, missingWitnessRedeemScript
}
