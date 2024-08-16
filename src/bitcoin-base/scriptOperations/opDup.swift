import Foundation

/// Duplicates the top stack item.
func opDup(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    stack.append(first)
    stack.append(first)
}
