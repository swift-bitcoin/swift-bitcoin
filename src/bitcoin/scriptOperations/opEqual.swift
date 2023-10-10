import Foundation

/// Returns 1 if the inputs are exactly equal, 0 otherwise.
func opEqual(_ stack: inout [Data]) throws {
    let (first, second) = try getBinaryParams(&stack)
    stack.append(ScriptBoolean(first == second).data)
}
