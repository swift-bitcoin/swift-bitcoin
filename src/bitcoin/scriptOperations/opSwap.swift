import Foundation

/// The top two items on the stack are swapped.
func opSwap(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    stack.append(second)
    stack.append(first)
}
