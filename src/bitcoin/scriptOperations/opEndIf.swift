import Foundation

/// Ends an if/else block. All blocks must end, or the transaction is invalid. An `OP_ENDIF` without `OP_IF` earlier is also invalid.
func opEndIf(context: inout ScriptContext) throws {
    guard !context.pendingIfOperations.isEmpty else {
        throw ScriptError.malformedIfElseEndIf // End if with no corresponding previous if
    }
    if context.pendingElseOperations == context.pendingIfOperations.count {
        context.pendingElseOperations -= 1 // try opElse(context: &context)
    } else if context.pendingElseOperations != context.pendingIfOperations.count - 1 {
        throw ScriptError.malformedIfElseEndIf // Unbalanced else
    }
    context.pendingIfOperations.removeLast()
}
