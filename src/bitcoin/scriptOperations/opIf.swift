import Foundation

/// If the top stack value is not False, the statements are executed. The top stack value is removed.
/// For the `isNotIf` variant, if the top stack value is False, the statements are executed. The top stack value is removed.
func opIf(_ stack: inout [Data], isNotIf: Bool = false, context: inout ScriptContext) throws {
    context.pendingElseOperations += 1
    guard context.evaluateBranch else {
        context.pendingIfOperations.append(.none)
        return
    }
    let first = try getUnaryParam(&stack)
    let condition = if context.script.version == .witnessV0 && context.configuration.minimalIf {
        try ScriptBoolean(minimalData: first)
    } else {
        ScriptBoolean(first)
    }
    let evalIfBranch = (!isNotIf && condition.value) || (isNotIf && !condition.value)
    context.pendingIfOperations.append(evalIfBranch)
}
