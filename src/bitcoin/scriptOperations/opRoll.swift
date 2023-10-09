import Foundation

/// The item n back in the stack is moved to the top.
func opRoll(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    let i = try ScriptNumber(first).value
    guard stack.count >= i else {
        throw ScriptError.invalidScript
    }
    let rolled = stack.remove(at: stack.endIndex - i)
    stack.append(rolled)
}
