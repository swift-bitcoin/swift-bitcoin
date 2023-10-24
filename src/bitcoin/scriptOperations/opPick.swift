import Foundation

/// The item n back in the stack is copied to the top.
func opPick(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    let n = try ScriptNumber(first).value
    guard n >= 0 && n < stack.count else {
        throw ScriptError.invalidStackOperation
    }
    let picked = stack[stack.endIndex - n - 1]
    stack.append(picked)
}
