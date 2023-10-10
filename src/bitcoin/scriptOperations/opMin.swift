import Foundation

/// Returns the smaller of a and b.
func opMin(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    let a = try ScriptNumber(first)
    let b = try ScriptNumber(second)
    stack.append((a.value < b.value ? a : b).data)
}
