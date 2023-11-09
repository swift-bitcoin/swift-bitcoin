import Foundation

/// Compares the first signature against each public key until it finds an ECDSA match. Starting with the subsequent public key, it compares the second signature against each remaining public key until it finds an ECDSA match. The process is repeated until all signatures have been checked or not enough public keys remain to produce a successful result. All signatures need to match a public key. Because public keys are not checked again if they fail any signature comparison, signatures must be placed in the `scriptSig` using the same order as their corresponding public keys were placed in the `scriptPubKey` or `redeemScript`. If all signatures are valid, `1` is returned, `0` otherwise. Due to a bug, one extra unused value is removed from the stack.
func opCheckMultiSig(_ stack: inout [Data], context: ScriptContext) throws {
    let (n, publicKeys, m, sigs) = try getCheckMultiSigParams(&stack, configuration: context.configuration)
    precondition(m <= n)
    precondition(publicKeys.count == n)
    precondition(sigs.count == m)

    guard let scriptCode = context.getScriptCode(signatures: sigs) else {
        throw ScriptError.invalidScript
    }

    var keysCount = publicKeys.count
    var sigsCount = sigs.count
    var keyIndex = publicKeys.startIndex
    var sigIndex = sigs.startIndex
    var success = true
    while success && sigsCount > 0 {
        let sig = sigs[sigIndex]
        let pubKey =  publicKeys[keyIndex]

        // Note how this makes the exact order of pubkey/signature evaluation
        // distinguishable by CHECKMULTISIG NOT if the STRICTENC flag is set.
        // See the script_(in)valid tests for details.
        switch context.script.version {
        case .legacy: try checkPublicKey(pubKey, scriptConfiguration: context.configuration)
        default: preconditionFailure() // TODO: SegWit will require compressed public keys
        }

        // Check signature
        var ok = false
        switch context.script.version {
        case .legacy:
            try checkSignature(sig, scriptConfiguration: context.configuration)
            ok = context.transaction.verifySignature(extendedSignature: sig, publicKey: pubKey, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
        default: preconditionFailure()
        }

        if ok {
            sigIndex += 1
            sigsCount -= 1
        }
        keyIndex += 1
        keysCount -= 1

        // If there are more signatures left than keys left,
        // then too many signatures have failed. Exit early,
        // without checking any further signatures.
        if sigsCount > keysCount { success = false }
    }

    stack.append(ScriptBoolean(success).data)
}
