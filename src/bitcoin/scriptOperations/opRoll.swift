import Foundation

/// The item n back in the stack is moved to the top.
func opRoll(_ stack: inout [Data], context: inout ScriptContext) throws {
    let n = try getUnaryNumericParam(&stack, context: &context).value
    guard n >= 0 && n < stack.count else {
        throw ScriptError.invalidStackOperation
    }
    let rolled = stack.remove(at: stack.endIndex - n - 1)
    stack.append(rolled)
}
