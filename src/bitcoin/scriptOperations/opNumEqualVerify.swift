import Foundation

/// Same as `OP_NUMEQUAL`,  but runs `OP_VERIFY` afterward.
func opNumEqualVerify(_ stack: inout [Data]) throws {
    try opNumEqual(&stack)
    try opVerify(&stack)
}
