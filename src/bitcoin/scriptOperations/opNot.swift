import Foundation

/// If the input is 0 or 1, it is flipped. Otherwise the output will be 0.
func opNot(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    let a = try ScriptNumber(first)
    stack.append(ScriptBoolean(a == .zero).data)
}
