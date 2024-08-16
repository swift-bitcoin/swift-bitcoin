import Foundation

/// Copies the pair of items two spaces back in the stack to the front.
func op2Over(_ stack: inout [Data]) throws {
    let (x1, x2, x3, x4) = try getQuaternaryParams(&stack)
    stack.append(x1)
    stack.append(x2)
    stack.append(x3)
    stack.append(x4)
    stack.append(x1)
    stack.append(x2)
}
