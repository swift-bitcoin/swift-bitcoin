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

        if sig.isEmpty {
            result = false
        } else {
            let (signature, sighashType) = splitECDSASignature(sig)
            let sighash = if context.version == .base {
                context.transaction.signatureHash(sighashType: sighashType, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
            } else if context.version == .witnessV0 {
                context.transaction.signatureHashSegwit(sighashType: sighashType, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
            } else { preconditionFailure() }
            result = verifyECDSA(sig: signature, msg: sighash, publicKey: publicKey)
        }
    case .witnessV1:
        guard let tapLeafHash = context.tapLeafHash, let keyVersion = context.keyVersion else { preconditionFailure() }
        // Tapscript semantics
        let ext = TapscriptExtension(tapLeafHash: tapLeafHash, keyVersion: keyVersion, codesepPos: context.codeSeparatorPosition)
        let (signature, sighashType) = try splitSchnorrSignature(sig)
        var cache = SighashCache() // TODO: Hold on to cache.
        let sighash = context.transaction.signatureHashSchnorr(sighashType: sighashType, inputIndex: context.inputIndex, previousOutputs: context.previousOutputs, tapscriptExtension: ext, sighashCache: &cache)
        result = verifySchnorr(sig: signature, msg: sighash, publicKey: publicKey)
    }

    if !result && context.configuration.nullFail && !sig.isEmpty {
        throw ScriptError.signatureNotEmpty
    }

    stack.append(ScriptBoolean(result).data)
}
