import Foundation

/// All of the signature checking words will only match signatures to the data after the most recently-executed `OP_CODESEPARATOR`
func opCodeSeparator(context: inout ScriptContext) {
    context.lastCodeSeparatorOffset = context.programCounter
}
