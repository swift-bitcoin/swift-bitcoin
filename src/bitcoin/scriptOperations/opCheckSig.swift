import Foundation

/// The entire transaction's outputs, inputs, and script (from the most recently-executed `OP_CODESEPARATOR` to the end) are hashed. The signature used by `OP_CHECKSIG` must be a valid signature for this hash and public key. If it is, `1` is returned, `0` otherwise.
func opCheckSig(_ stack: inout [Data], context: ScriptContext) throws {
    let (sig, publicKey) = try getBinaryParams(&stack)

    let result: Bool
    switch context.script.version {
        case .legacy:
        // Legacy semantics
        guard let scriptCode = context.getScriptCode(signature: sig) else {
            throw ScriptError.invalidScript
        }
        try checkSignature(sig, scriptConfiguration: context.configuration)
        result = context.transaction.verifySignature(extendedSignature: sig, publicKey: publicKey, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
        default:
            preconditionFailure()
    }
    stack.append(ScriptBoolean(result).data)
}
