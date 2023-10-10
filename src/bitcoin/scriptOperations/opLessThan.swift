import Foundation

/// Returns 1 if a is less than b, 0 otherwise.
func opLessThan(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    let a = try ScriptNumber(first)
    let b = try ScriptNumber(second)
    stack.append(ScriptBoolean(a.value < b.value).data)
}
