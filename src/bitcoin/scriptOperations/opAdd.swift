import Foundation

/// a is added to b.
func opAdd(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    var a = try ScriptNumber(first)
    let b = try ScriptNumber(second)
    try a.add(b)
    stack.append(a.data)
}
