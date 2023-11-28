import Foundation

/// An error while executing a bitcoin script.
enum ScriptError: Error {
    case invalidScript,
         unparsableScript,
         nonPushOnlyScript,
         invalidStackOperation,
         unparsableOperation,
         unknownOperation,
         disabledOperation,
         numberOverflow,
         nonMinimalBoolean,
         nonLowSSignature,
         invalidPublicKeyEncoding,
         invalidSignatureEncoding,
         undefinedSighashType,
         missingDummyValue,
         dummyValueNotNull,
         invalidLockTimeArgument,
         lockTimeHeightEarly,
         lockTimeSecondsEarly,
         inputSequenceFinal,
         missingStackArgument,
         scriptSigNotEmpty,
         falseReturned,
         scriptSigTooManyPushes,
         uncleanStack,
         wrongWitnessScriptHash,
         witnessProgramWrongLength,
         witnessScriptTooBig,
         witnessElementTooBig,
         disallowedWitnessVersion,
         nonConstantScript,
         signatureNotEmpty,
         tapscriptCheckMultiSigDisabled,
         invalidSchnorrSignature,
         invalidSchnorrSignatureFormat,
         invalidTapscriptControlBlock,
         invalidTaprootPublicKey,
         invalidTaprootTweak,
         missingTaprootWitness,
         disallowedTaprootVersion,
         sigopBudgetExceeded
}
