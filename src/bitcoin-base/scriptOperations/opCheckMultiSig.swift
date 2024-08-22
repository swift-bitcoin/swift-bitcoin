import Foundation
import BitcoinCrypto

/// Compares the first signature against each public key until it finds an ECDSA match. Starting with the subsequent public key, it compares the second signature against each remaining public key until it finds an ECDSA match. The process is repeated until all signatures have been checked or not enough public keys remain to produce a successful result. All signatures need to match a public key. Because public keys are not checked again if they fail any signature comparison, signatures must be placed in the `scriptSig` using the same order as their corresponding public keys were placed in the `scriptPubKey` or `redeemScript`. If all signatures are valid, `1` is returned, `0` otherwise. Due to a bug, one extra unused value is removed from the stack.
func opCheckMultiSig(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (n, publicKeys, m, sigs) = try getCheckMultiSigParams(&stack, config: context.config)
    precondition(m <= n)
    precondition(publicKeys.count == n)
    precondition(sigs.count == m)

    guard n <= BitcoinScript.maxMultiSigPublicKeys else {
        throw ScriptError.maxPublicKeysExceeded
    }

    context.nonPushOperations += n
    guard context.nonPushOperations <= BitcoinScript.maxOperations else {
        throw ScriptError.operationsLimitExceeded
    }

    let scriptCode = try context.sigVersion == .base ? context.getScriptCode(signatures: sigs) : context.segwitScriptCode

    var keysCount = publicKeys.count
    var sigsCount = sigs.count
    var keyIndex = publicKeys.startIndex
    var sigIndex = sigs.startIndex
    var success = true
    while success && sigsCount > 0 {
        let extendedSignatureData = sigs[sigIndex]
        let publicKeyData =  publicKeys[keyIndex]

        // Note how this makes the exact order of pubkey/signature evaluation
        // distinguishable by CHECKMULTISIG NOT if the STRICTENC flag is set.
        // See the script_(in)valid tests for details.
        // TODO: Could this be refactored into generic PublicKey struct?
        try checkPublicKey(publicKeyData, scriptVersion: context.sigVersion, scriptConfig: context.config)

        // Check signature
        try checkSignature(extendedSignatureData, scriptConfig: context.config)
        let ok: Bool
        if extendedSignatureData.isEmpty {
            ok = false
        } else {
            let (signatureData, sighashType) = splitECDSASignature(extendedSignatureData)
            let sighash = if context.sigVersion == .base {
                context.transaction.signatureHash(sighashType: sighashType, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
            } else if context.sigVersion == .witnessV0 {
                context.transaction.signatureHashSegwit(sighashType: sighashType, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
            } else { preconditionFailure() }
            if let publicKey = PublicKey(publicKeyData), let signature = Signature(signatureData, type: .ecdsa) {
                ok = signature.verify(messageHash: sighash, publicKey: publicKey)
            } else {
                ok = false
            }
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

    if !success && context.config.contains(.nullFail) && !sigs.allSatisfy(\.isEmpty) {
        throw ScriptError.signatureNotEmpty
    }

    stack.append(ScriptBoolean(success).data)
}
