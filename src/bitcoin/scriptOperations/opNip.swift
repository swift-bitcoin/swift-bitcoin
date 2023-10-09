import Foundation

/// Removes the second-to-top stack item.
func opNip(_ stack: inout [Data]) throws {
    let (_, second) = try getBinaryParams(&stack)
    stack.append(second)
}
