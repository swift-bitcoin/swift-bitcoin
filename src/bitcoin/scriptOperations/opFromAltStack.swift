import Foundation

/// Puts the input onto the top of the main stack. Removes it from the alt stack.
func opFromAltStack(_ stack: inout [Data], context: inout ScriptContext) throws {
    guard context.altStack.count > 0 else {
        throw ScriptError.missingAltStackArgument
    }
    stack.append(context.altStack.removeLast())
}
