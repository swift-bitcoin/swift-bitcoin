import Foundation

/// All of the signature checking words will only match signatures to the data after the most recently-executed `OP_CODESEPARATOR`
func opCodeSeparator(context: inout ScriptContext) throws {
    if context.version == .base && context.configuration.constantScriptCode {
        throw ScriptError.nonConstantScript
    }
    guard context.evaluateBranch else { return }
    context.lastCodeSeparatorOffset = context.programCounter
}
