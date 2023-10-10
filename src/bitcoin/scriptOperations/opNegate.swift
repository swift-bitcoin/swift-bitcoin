import Foundation

/// The sign of the input is flipped.
func opNegate(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    var a = try ScriptNumber(first)
    a.negate()
    stack.append(a.data)
}
