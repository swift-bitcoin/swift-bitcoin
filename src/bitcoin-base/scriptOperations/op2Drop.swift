import Foundation

/// Removes the top two stack items.
func op2Drop(_ stack: inout [Data]) throws {
    _ = try getBinaryParams(&stack)
}
