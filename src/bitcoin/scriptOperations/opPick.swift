import Foundation

/// The item n back in the stack is copied to the top.
func opPick(_ stack: inout [Data], context: inout ScriptContext) throws {
    let n = try getUnaryNumericParam(&stack, context: &context).value
    guard n >= 0 && n < stack.count else {
        throw ScriptError.invalidStackOperation
    }
    let picked = stack[stack.endIndex - n - 1]
    stack.append(picked)
}
