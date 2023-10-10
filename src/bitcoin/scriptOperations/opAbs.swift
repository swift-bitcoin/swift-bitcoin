import Foundation

/// The input is made positive.
func opAbs(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    var a = try ScriptNumber(first)
    if a.value < 0 {
        a.negate()
    }
    stack.append(a.data)
}
