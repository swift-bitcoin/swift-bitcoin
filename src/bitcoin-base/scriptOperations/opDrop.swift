import Foundation

/// Removes the top stack item.
func opDrop(_ stack: inout [Data]) throws {
    _ = try getUnaryParam(&stack)
}
