import Foundation

/// The fifth and sixth items back are moved to the top of the stack.
func op2Rot(_ stack: inout [Data]) throws {
    let (x1, x2, x3, x4, x5, x6) = try getSenaryParams(&stack)
    stack.append(x3)
    stack.append(x4)
    stack.append(x5)
    stack.append(x6)
    stack.append(x1)
    stack.append(x2)
}
