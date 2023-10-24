import Foundation

/// An error while executing a bitcoin script.
enum ScriptError: Error {
    case invalidScript,
         invalidStackOperation,
         invalidInstruction,
         disabledOperation,
         numberOverflow,
         nonMinimalBoolean,
         nonLowSSignature,
         invalidPublicKeyEncoding,
         invalidSignatureEncoding,
         undefinedSighashType
}
