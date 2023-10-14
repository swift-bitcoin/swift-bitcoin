import Foundation

func opCheckSigVerify(_ stack: inout [Data], context: ScriptContext) throws {
    try opCheckSig(&stack, context: context)
    try opVerify(&stack)
}
