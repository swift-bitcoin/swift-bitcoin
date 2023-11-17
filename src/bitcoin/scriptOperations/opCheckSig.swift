import Foundation

/// The entire transaction's outputs, inputs, and script (from the most recently-executed `OP_CODESEPARATOR` to the end) are hashed. The signature used by `OP_CHECKSIG` must be a valid signature for this hash and public key. If it is, `1` is returned, `0` otherwise.
func opCheckSig(_ stack: inout [Data], context: ScriptContext) throws {
    let (sig, publicKey) = try getBinaryParams(&stack)

    let scriptCode = try context.script.version == .legacy ? context.getScriptCode(signatures: [sig]) : context.segwitScriptCode

    try checkPublicKey(publicKey, scriptVersion: context.script.version, scriptConfiguration: context.configuration)

    try checkSignature(sig, scriptConfiguration: context.configuration)

    let result = context.transaction.verifySignature(extendedSignature: sig, publicKey: publicKey, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode, scriptVersion: context.script.version)

    if !result && context.configuration.nullFail && !sig.isEmpty {
        throw ScriptError.signatureNotEmpty
    }

    stack.append(ScriptBoolean(result).data)
}
