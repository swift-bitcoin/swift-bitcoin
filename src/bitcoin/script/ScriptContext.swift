import Foundation

/// SCRIPT execution context.
struct ScriptContext {
    let transaction: Transaction
    let inputIndex: Int
    let previousOutputs: [Output]
    let script: any Script
    var decodedOperations = [ScriptOperation]()
    var operationIndex: Int = 0
    var programCounter: Int = 0
    var altStack: [Data] = []

    // Flow control ops (`OP_IF` et al) support
    var pendingIfOperations = [Bool?]()
    var pendingElseOperations = 0

    var previousOutput: Output {
        previousOutputs[inputIndex]
    }

    var evaluateBranch: Bool {
        guard let lastEvaluatedIfResult = pendingIfOperations.last(where: { $0 != .none }), let lastEvaluatedIfResult else {
            return true
        }
        return lastEvaluatedIfResult
    }
}
