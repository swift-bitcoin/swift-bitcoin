import Foundation

/// BIP342: Three values are popped from the stack. The integer n is incremented by one and returned to the stack if the signature is valid for the public key and transaction. The integer n is returned to the stack unchanged if the signature is the empty vector (OP_0). In any other case, the script is invalid. This opcode is only available in tapscript.
func opCheckSigAdd(_ stack: inout [Data], context: inout ScriptContext) throws {

    guard let tapLeafHash = context.tapLeafHash, let keyVersion = context.keyVersion else {
        preconditionFailure()
    }

    // If fewer than 3 elements are on the stack, the script MUST fail and terminate immediately.
    let (sig, nData, publicKey) = try getTernaryParams(&stack)

    var n = try ScriptNumber(nData)
    guard n.size <= 4 else {
        // - If n is larger than 4 bytes, the script MUST fail and terminate immediately.
        throw ScriptError.invalidScript
    }

    if publicKey.isEmpty {
        // - If the public key size is zero, the script MUST fail and terminate immediately.
        throw ScriptError.invalidScript
    }

    if !sig.isEmpty { try context.checkSigopBudget() }

    if publicKey.count == 32 && !sig.isEmpty {

        // If the public key size is 32 bytes, it is considered to be a public key as described in BIP340:
        // If the signature is not the empty vector, the signature is validated against the public key (see the next subsection). Validation failure in this case immediately terminates script execution with failure.

        // Tapscript semantics
        let ext = TapscriptExtension(tapLeafHash: tapLeafHash, keyVersion: keyVersion, codesepPos: context.codeSeparatorPosition)
        let (signature, sighashType) = try splitSchnorrSignature(sig)
        var cache = SighashCache() // TODO: Hold on to cache.
        let sighash = context.transaction.signatureHashSchnorr(sighashType: sighashType, inputIndex: context.inputIndex, previousOutputs: context.previousOutputs, tapscriptExtension: ext, sighashCache: &cache)
        let result = verifySchnorr(sig: signature, msg: sighash, publicKey: publicKey)
        if !result { throw ScriptError.invalidSchnorrSignature }
    } else if publicKey.isEmpty {
        throw ScriptError.emptyPublicKey
    } else {
        // If the public key size is not zero and not 32 bytes, the public key is of an unknown public key type and no actual signature verification is applied. During script execution of signature opcodes they behave exactly as known public key types except that signature validation is considered to be successful.
        if context.configuration.discourageUpgradablePublicKeyType {
            throw ScriptError.disallowsPublicKeyType
        }
    }

    // If the script did not fail and terminate before this step, regardless of the public key type:
    if sig.isEmpty {
        // If the signature is the empty vector:
        // For OP_CHECKSIGADD, a CScriptNum with value n is pushed onto the stack, and execution continues with the next opcode.
        stack.append(nData)
    } else {
        // If the signature is not the empty vector, the opcode is counted towards the sigops budget (see further).
        // For OP_CHECKSIGADD, a CScriptNum with value of n + 1 is pushed onto the stack.
        try n.add(.one)
        stack.append(n.data)
    }
}
