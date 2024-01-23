import Foundation

/// Same as `OP_NUMEQUAL`,  but runs `OP_VERIFY` afterward.
func opNumEqualVerify(_ stack: inout [Data], context: inout ScriptContext) throws {
    try opNumEqual(&stack, context: &context)
    try opVerify(&stack)
}
