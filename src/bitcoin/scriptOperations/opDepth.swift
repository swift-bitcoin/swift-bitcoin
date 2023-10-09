import Foundation

/// Puts the number of stack items onto the stack.
func opDepth(_ stack: inout [Data]) throws {
    let count = try ScriptNumber(stack.count)
    stack.append(count.data)
}
