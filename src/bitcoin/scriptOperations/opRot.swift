import Foundation

/// The 3rd item down the stack is moved to the top.
func opRot(_ stack: inout [Data]) throws {
    let (first, second, third) = try getTernaryParams(&stack)
    stack.append(second)
    stack.append(third)
    stack.append(first)
}
