import Foundation

/// Compares the first signature against each public key until it finds an ECDSA match. Starting with the subsequent public key, it compares the second signature against each remaining public key until it finds an ECDSA match. The process is repeated until all signatures have been checked or not enough public keys remain to produce a successful result. All signatures need to match a public key. Because public keys are not checked again if they fail any signature comparison, signatures must be placed in the `scriptSig` using the same order as their corresponding public keys were placed in the `scriptPubKey` or `redeemScript`. If all signatures are valid, `1` is returned, `0` otherwise. Due to a bug, one extra unused value is removed from the stack.
func opCheckMultiSig(_ stack: inout [Data], context: ScriptContext) throws {
    let (n, publicKeys, m, sigs) = try getCheckMultiSigParams(&stack, configuration: context.configuration)
    precondition(m <= n)
    precondition(publicKeys.count == n)
    precondition(sigs.count == m)
    var leftPubKeys = publicKeys
    var leftSigs = sigs
    while leftPubKeys.count > 0 && leftSigs.count > 0 {
        let publicKey = leftPubKeys.removeFirst()
        var result = false
        var i = 0
        while i < leftSigs.count {
            switch context.script.version {
                case .legacy:
                guard let scriptCode = context.getScriptCode(signature: leftSigs[i]) else {
                    throw ScriptError.invalidScript
                }
                try checkSignature(leftSigs[i], scriptConfiguration: context.configuration)
                result = context.transaction.verifySignature(extendedSignature: leftSigs[i], publicKey: publicKey, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
                default: preconditionFailure()
            }
            if result {
                break
            }
            i += 1
        }
        if result {
            leftSigs.remove(at: i)
        }
    }
    stack.append(ScriptBoolean(leftSigs.count == 0).data)
}
