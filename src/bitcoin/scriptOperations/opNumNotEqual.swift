import Foundation

/// Returns 1 if the numbers are not equal, 0 otherwise.
func opNumNotEqual(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    let a = try ScriptNumber(first)
    let b = try ScriptNumber(second)
    stack.append(ScriptBoolean(a != b).data)
}
