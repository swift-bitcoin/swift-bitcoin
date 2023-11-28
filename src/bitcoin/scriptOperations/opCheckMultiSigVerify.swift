import Foundation

/// Same as `OP_CHECKMULTISIG`' but `OP_VERIFY` is executed afterward.
func opCheckMultiSigVerify(_ stack: inout [Data], context: inout ScriptContext) throws {
    try opCheckMultiSig(&stack, context: &context)
    try opVerify(&stack)
}
