import Foundation

/// An error while executing a bitcoin script.
enum ScriptError: Error {
    case invalidScript,
         unparsableScript,
         nonPushOnlyScript,
         invalidStackOperation,
         invalidInstruction,
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
         missingStackArgument
}
