import Foundation

/// An error while executing a bitcoin script.
enum ScriptError: Error {
    case invalidScript,
         invalidInstruction,
         disabledOperation,
         numberOverflow,
         nonMinimalBoolean,
         nonLowSSignature,
         invalidSignatureEncoding
}
