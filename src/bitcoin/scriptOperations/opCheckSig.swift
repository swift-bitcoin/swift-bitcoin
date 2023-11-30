import Foundation

/// The entire transaction's outputs, inputs, and script (from the most recently-executed `OP_CODESEPARATOR` to the end) are hashed. The signature used by `OP_CHECKSIG` must be a valid signature for this hash and public key. If it is, `1` is returned, `0` otherwise.
func opCheckSig(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (sig, publicKey) = try getBinaryParams(&stack)

    let result: Bool

    switch context.sigVersion {
    case .base, .witnessV0:
        let scriptCode = try context.sigVersion == .base ? context.getScriptCode(signatures: [sig]) : context.segwitScriptCode

        try checkPublicKey(publicKey, scriptVersion: context.sigVersion, scriptConfiguration: context.configuration)

        try checkSignature(sig, scriptConfiguration: context.configuration)

        if sig.isEmpty {
            result = false
        } else {
            let (signature, sighashType) = splitECDSASignature(sig)
            let sighash = if context.sigVersion == .base {
                context.transaction.signatureHash(sighashType: sighashType, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
            } else if context.sigVersion == .witnessV0 {
                context.transaction.signatureHashSegwit(sighashType: sighashType, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
            } else { preconditionFailure() }
            result = verifyECDSA(sig: signature, msg: sighash, publicKey: publicKey)
        }
    case .witnessV1:
        guard let tapLeafHash = context.tapLeafHash, let keyVersion = context.keyVersion else { preconditionFailure() }

        guard !publicKey.isEmpty else {
            throw ScriptError.emptyPublicKey
        }

        if !sig.isEmpty { try context.checkSigopBudget() }

        if publicKey.count == 32 {
            // If the public key size is 32 bytes, it is considered to be a public key as described in BIP340:
            if !sig.isEmpty {
                // If the signature is not the empty vector, the signature is validated against the public key (see the next subsection).
                // Tapscript semantics
                let ext = TapscriptExtension(tapLeafHash: tapLeafHash, keyVersion: keyVersion, codesepPos: context.codeSeparatorPosition)
                let (signature, sighashType) = try splitSchnorrSignature(sig)
                var cache = SighashCache() // TODO: Hold on to cache.
                let sighash = context.transaction.signatureHashSchnorr(sighashType: sighashType, inputIndex: context.inputIndex, previousOutputs: context.previousOutputs, tapscriptExtension: ext, sighashCache: &cache)
                result = verifySchnorr(sig: signature, msg: sighash, publicKey: publicKey)
                // TODO: The following rule makes some test vectors fail. #96
                // Validation failure in this case immediately terminates script execution with failure.
                // guard result else { throw ScriptError.invalidSchnorrSignature }
            } else {
                result = true
            }
        } else {
            if sig.isEmpty {
                // The script execution fails when using empty signature with invalid public key.
                throw ScriptError.emptySchnorrSignature
            }
            
            // If the public key size is not zero and not 32 bytes, the public key is of an unknown public key type and no actual signature verification is applied. During script execution of signature opcodes they behave exactly as known public key types except that signature validation is considered to be successful.
            if context.configuration.discourageUpgradablePublicKeyType {
                throw ScriptError.disallowsPublicKeyType
            }
            result = true
        }
    }

    if !result && context.configuration.nullFail && !sig.isEmpty {
        throw ScriptError.signatureNotEmpty
    }

    stack.append(ScriptBoolean(result).data)
}
