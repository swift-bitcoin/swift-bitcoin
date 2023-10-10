import Foundation

/// If a or b is not 0, the output is 1. Otherwise 0.
func opBoolOr(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    let a = try ScriptNumber(first)
    let b = try ScriptNumber(second)
    stack.append(ScriptBoolean(a != .zero || b != .zero).data)
}
