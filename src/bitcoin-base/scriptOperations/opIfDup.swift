import Foundation

/// If the top stack value is not 0, duplicate it.
func opIfDup(_ stack: inout [Data]) throws {
    guard let top = stack.last else {
        throw ScriptError.missingStackArgument
    }
    if top.isEmpty {
        return
    }
    try opDup(&stack)
}
