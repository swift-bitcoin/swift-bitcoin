import Foundation

/// Returns 0 if the input is 0. 1 otherwise.
func op0NotEqual(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    let a = try ScriptNumber(first)
    stack.append(ScriptBoolean(a != .zero).data)
}
