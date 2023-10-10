import Foundation

/// Returns the larger of a and b.
func opMax(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    let a = try ScriptNumber(first)
    let b = try ScriptNumber(second)
    stack.append((a.value > b.value ? a : b).data)
}
