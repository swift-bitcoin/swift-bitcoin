import Foundation

extension ScriptContext {

    /// If the top stack value is not False, the statements are executed. The top stack value is removed.
    /// For the `isNotIf` variant, if the top stack value is False, the statements are executed. The top stack value is removed.
    mutating func opIf(isNotIf: Bool = false) throws {
        pendingElseOperations += 1
        guard evaluateBranch else {
            pendingIfOperations.append(.none)
            return
        }
        let first = try getUnaryParam()
        let condition = if sigVersion == .witnessV0 && config.contains(.minimalIf) {
            try ScriptBoolean(minimalData: first)
        } else {
            ScriptBoolean(first)
        }
        let evalIfBranch = (!isNotIf && condition.value) || (isNotIf && !condition.value)
        pendingIfOperations.append(evalIfBranch)
    }

    /// If the preceding `OP_IF` or `OP_NOTIF` or `OP_ELSE` was not executed then these statements are and if the preceding `OP_IF` or `OP_NOTIF` or `OP_ELSE` was executed then these statements are not.
    mutating func opElse() throws {
        guard pendingElseOperations > 0, pendingElseOperations == pendingIfOperations.count else {
            throw ScriptError.malformedIfElseEndIf // Else with no corresponding previous if
        }
        pendingElseOperations -= 1
        guard let lastEvaluatedIfResult = pendingIfOperations.last, let lastEvaluatedIfResult else {
            return
        }
        pendingIfOperations[pendingIfOperations.endIndex - 1] = !lastEvaluatedIfResult
    }

    /// Ends an if/else block. All blocks must end, or the transaction is invalid. An `OP_ENDIF` without `OP_IF` earlier is also invalid.
    mutating func opEndIf() throws {
        guard !pendingIfOperations.isEmpty else {
            throw ScriptError.malformedIfElseEndIf // End if with no corresponding previous if
        }
        if pendingElseOperations == pendingIfOperations.count {
            pendingElseOperations -= 1 // try opElse(context: &context)
        } else if pendingElseOperations != pendingIfOperations.count - 1 {
            throw ScriptError.malformedIfElseEndIf // Unbalanced else
        }
        pendingIfOperations.removeLast()
    }

    /// All of the signature checking words will only match signatures to the data after the most recently-executed `OP_CODESEPARATOR`
    mutating func opCodeSeparator() throws {
        if sigVersion == .base && config.contains(.constantScriptCode) {
            throw ScriptError.nonConstantScript
        }
        guard evaluateBranch else { return }
        lastCodeSeparatorOffset = programCounter
        lastCodeSeparatorIndex = operationIndex
    }

    /// Marks transaction as invalid if top stack value is not true. The top stack value is removed.
    mutating func opVerify() throws {
        let first = try getUnaryParam()
        guard ScriptBoolean(first).value else {
            throw ScriptError.falseReturned
        }
    }

    /// Returns 1 if the inputs are exactly equal, 0 otherwise.
    mutating func opEqual() throws {
        let (first, second) = try getBinaryParams()
        stack.append(ScriptBoolean(first == second).data)
    }

    /// Same as ``opEqual`` (`OP_EQUAL`), but runs  ``opVerify`` (`OP_VERIFY`) afterward.
    mutating func opEqualVerify() throws {
        try opEqual()
        try opVerify()
    }
}
