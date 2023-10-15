import Foundation

/// Same as `OP_CHECKSIG`, but `OP_VERIFY` is executed afterward.
func opCheckSigVerify(_ stack: inout [Data], context: ScriptContext) throws {
    try opCheckSig(&stack, context: context)
    try opVerify(&stack)
}
