import Foundation

/// Copies the second-to-top stack item to the top.
func opOver(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    stack.append(first)
    stack.append(second)
    stack.append(first)
}
