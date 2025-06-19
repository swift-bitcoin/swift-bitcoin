import Foundation

extension ScriptRuntime {

    /// If the top stack value is not False, the statements are executed. The top stack value is removed.
    /// For the `isNotIf` variant, if the top stack value is False, the statements are executed. The top stack value is removed.
    mutating func opIf(isNotIf: Bool = false) throws {
        pendingElseOps += 1
        guard evaluateBranch else {
            pendingIfOps.append(nil)
            return
        }
        let first = try getUnaryParam()
        let condition = if sigVersion == .witnessV0 && config.contains(.minimalIf) {
            try ScriptBool(minimalData: first)
        } else {
            ScriptBool(first)
        }
        let evalIfBranch = (!isNotIf && condition.value) || (isNotIf && !condition.value)
        pendingIfOps.append(evalIfBranch)
    }

    /// If the preceding `OP_IF` or `OP_NOTIF` or `OP_ELSE` was not executed then these statements are and if the preceding `OP_IF` or `OP_NOTIF` or `OP_ELSE` was executed then these statements are not.
    mutating func opElse() throws {
        guard pendingElseOps > 0, pendingElseOps == pendingIfOps.count else {
            throw ScriptError.malformedIfElseEndIf // Else with no corresponding previous if
        }
        pendingElseOps -= 1
        guard let lastEvaluatedIfResult = pendingIfOps.last, let lastEvaluatedIfResult else {
            return
        }
        pendingIfOps[pendingIfOps.endIndex - 1] = !lastEvaluatedIfResult
    }

    /// Ends an if/else block. All blocks must end, or the transaction is invalid. An `OP_ENDIF` without `OP_IF` earlier is also invalid.
    mutating func opEndIf() throws {
        guard !pendingIfOps.isEmpty else {
            throw ScriptError.malformedIfElseEndIf // End if with no corresponding previous if
        }
        if pendingElseOps == pendingIfOps.count {
            pendingElseOps -= 1 // try opElse(runtime: &runtime)
        } else if pendingElseOps != pendingIfOps.count - 1 {
            throw ScriptError.malformedIfElseEndIf // Unbalanced else
        }
        pendingIfOps.removeLast()
    }

    /// All of the signature checking words will only match signatures to the data after the most recently-executed `OP_CODESEPARATOR`
    mutating func opCodeSeparator() throws {
        if sigVersion == .base && config.contains(.constantScriptCode) {
            throw ScriptError.nonConstantScript
        }
        guard evaluateBranch else { return }
        lastCodeSeparatorOffset = programCounter
        lastCodeSeparatorIndex = opIndex
    }

    /// Marks transaction as invalid if top stack value is not true. The top stack value is removed.
    mutating func opVerify() throws {
        let first = try getUnaryParam()
        guard ScriptBool(first).value else {
            throw ScriptError.falseReturned
        }
    }

    /// Returns 1 if the inputs are exactly equal, 0 otherwise.
    mutating func opEqual() throws {
        let (first, second) = try getBinaryParams()
        stack.append(ScriptBool(first == second).data)
    }

    /// Same as ``opEqual`` (`OP_EQUAL`), but runs  ``opVerify`` (`OP_VERIFY`) afterward.
    mutating func opEqualVerify() throws {
        try opEqual()
        try opVerify()
    }
}
