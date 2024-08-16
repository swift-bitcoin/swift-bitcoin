import Foundation

/// If the preceding `OP_IF` or `OP_NOTIF` or `OP_ELSE` was not executed then these statements are and if the preceding `OP_IF` or `OP_NOTIF` or `OP_ELSE` was executed then these statements are not.
func opElse(context: inout ScriptContext) throws {
    guard context.pendingElseOperations > 0, context.pendingElseOperations == context.pendingIfOperations.count else {
        throw ScriptError.malformedIfElseEndIf // Else with no corresponding previous if
    }
    context.pendingElseOperations -= 1
    guard let lastEvaluatedIfResult = context.pendingIfOperations.last, let lastEvaluatedIfResult else {
        return
    }
    context.pendingIfOperations[context.pendingIfOperations.endIndex - 1] = !lastEvaluatedIfResult
}
