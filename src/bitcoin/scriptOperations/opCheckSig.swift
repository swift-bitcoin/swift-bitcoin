import Foundation

/// The entire transaction's outputs, inputs, and script (from the most recently-executed `OP_CODESEPARATOR` to the end) are hashed. The signature used by `OP_CHECKSIG` must be a valid signature for this hash and public key. If it is, `1` is returned, `0` otherwise.
func opCheckSig(_ stack: inout [Data], context: ScriptContext) throws {
    let (sig, publicKey) = try getBinaryParams(&stack)

    let result: Bool

    switch context.version {
    case .base, .witnessV0:
        let scriptCode = try context.version == .base ? context.getScriptCode(signatures: [sig]) : context.segwitScriptCode

        try checkPublicKey(publicKey, scriptVersion: context.version, scriptConfiguration: context.configuration)

        try checkSignature(sig, scriptConfiguration: context.configuration)

        result = context.transaction.checkECDSASignature(extendedSignature: sig, publicKey: publicKey, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode, scriptVersion: context.version)
    case .witnessV1:
        guard let tapLeafHash = context.tapLeafHash, let keyVersion = context.keyVersion else {
            preconditionFailure()
        }

        // Tapscript semantics
        result = context.transaction.checkSchnorrSignature(extendedSignature: sig, publicKey: publicKey, inputIndex: context.inputIndex, previousOutputs: context.previousOutputs, extFlag: 1, tapscriptExtension: .init(tapLeafHash: tapLeafHash, keyVersion: keyVersion, codesepPos: context.codeSeparatorPosition))
    }

    if !result && context.configuration.nullFail && !sig.isEmpty {
        throw ScriptError.signatureNotEmpty
    }

    stack.append(ScriptBoolean(result).data)
}
