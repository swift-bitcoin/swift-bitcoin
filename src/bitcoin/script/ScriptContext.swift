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

    var previousOutput: Output {
        previousOutputs[inputIndex]
    }
}
