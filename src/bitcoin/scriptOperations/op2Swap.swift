import Foundation

/// Swaps the top two pairs of items.
func op2Swap(_ stack: inout [Data]) throws {
    let (x1, x2, x3, x4) = try getQuaternaryParams(&stack)
    stack.append(x3)
    stack.append(x4)
    stack.append(x1)
    stack.append(x2)
}
