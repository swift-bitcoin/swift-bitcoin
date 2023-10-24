import Foundation

/// The item n back in the stack is moved to the top.
func opRoll(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    let n = try ScriptNumber(first).value
    guard n >= 0 && n < stack.count else {
        throw ScriptError.invalidStackOperation
    }
    let rolled = stack.remove(at: stack.endIndex - n - 1)
    stack.append(rolled)
}
