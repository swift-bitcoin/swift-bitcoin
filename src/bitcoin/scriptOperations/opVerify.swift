import Foundation

/// Marks transaction as invalid if top stack value is not true. The top stack value is removed.
func opVerify(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    guard ScriptBoolean(first).value else {
        throw ScriptError.invalidScript
    }
}
