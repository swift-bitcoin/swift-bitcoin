import Foundation

/// b is subtracted from a.
func op1Sub(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    var a = try ScriptNumber(first)
    try a.add(.negativeOne)
    stack.append(a.data)
}
