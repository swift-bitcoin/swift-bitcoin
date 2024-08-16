import Foundation

/// The item at the top of the stack is copied and inserted before the second-to-top item.
func opTuck(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    stack.append(second)
    stack.append(first)
    stack.append(second)
}
