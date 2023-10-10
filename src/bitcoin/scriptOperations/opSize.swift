import Foundation

/// Pushes the string length of the top element of the stack (without popping it).
func opSize(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    stack.append(first)
    let n = try ScriptNumber(first.count)
    stack.append(n.data)
}
