import Foundation
import BitcoinCrypto

extension ScriptContext {

    /// The entire transaction's outputs, inputs, and script (from the most recently-executed `OP_CODESEPARATOR` to the end) are hashed. The signature used by `OP_CHECKSIG` must be a valid signature for this hash and public key. If it is, `1` is returned, `0` otherwise.
    mutating func opCheckSig() throws {
        let (sig, publicKeyData) = try getBinaryParams()

        if sigVersion == .witnessV1 {
            try checkSigSchnorr(sig, publicKeyData)
            return
        }

        let scriptCode = try sigVersion == .base ? getScriptCode(signatures: [sig]) : segwitScriptCode
        let result = try checkSigECDSA(sig, publicKeyData, scriptCode: scriptCode)
        if !result && config.contains(.nullFail) && !sig.isEmpty {
            throw ScriptError.signatureNotEmpty
        }
        stack.append(ScriptBoolean(result).data)
    }

    /// Same as `OP_CHECKSIG`, but `OP_VERIFY` is executed afterward.
    mutating func opCheckSigVerify() throws {
        try opCheckSig()
        try opVerify()
    }

    /// Compares the first signature against each public key until it finds an ECDSA match. Starting with the subsequent public key, it compares the second signature against each remaining public key until it finds an ECDSA match. The process is repeated until all signatures have been checked or not enough public keys remain to produce a successful result. All signatures need to match a public key. Because public keys are not checked again if they fail any signature comparison, signatures must be placed in the `scriptSig` using the same order as their corresponding public keys were placed in the `scriptPubKey` or `redeemScript`. If all signatures are valid, `1` is returned, `0` otherwise. Due to a bug, one extra unused value is removed from the stack.
    mutating func opCheckMultiSig() throws {
        let (n, publicKeys, m, sigs) = try getCheckMultiSigParams()
        precondition(m <= n)
        precondition(publicKeys.count == n)
        precondition(sigs.count == m)

        guard n <= BitcoinScript.maxMultiSigPublicKeys else {
            throw ScriptError.maxPublicKeysExceeded
        }

        nonPushOperations += n
        guard nonPushOperations <= BitcoinScript.maxOperations else {
            throw ScriptError.operationsLimitExceeded
        }

        let scriptCode = try sigVersion == .base ? getScriptCode(signatures: sigs) : segwitScriptCode
        var keysCount = publicKeys.count
        var sigsCount = sigs.count
        var keyIndex = publicKeys.startIndex
        var sigIndex = sigs.startIndex
        var success = true
        while success && sigsCount > 0 {
            if try checkSigECDSA(sigs[sigIndex], publicKeys[keyIndex], scriptCode: scriptCode) {
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

        if !success && config.contains(.nullFail) && !sigs.allSatisfy(\.isEmpty) {
            throw ScriptError.signatureNotEmpty
        }

        stack.append(ScriptBoolean(success).data)
    }

    /// Same as `OP_CHECKMULTISIG`' but `OP_VERIFY` is executed afterward.
    mutating func opCheckMultiSigVerify() throws {
        try opCheckMultiSig()
        try opVerify()
    }


    /// BIP342: Three values are popped from the stack. The integer n is incremented by one and returned to the stack if the signature is valid for the public key and transaction. The integer n is returned to the stack unchanged if the signature is the empty vector (OP_0). In any other case, the script is invalid. This opcode is only available in tapscript.
    mutating func opCheckSigAdd() throws {
        // If fewer than 3 elements are on the stack, the script MUST fail and terminate immediately.
        let (sig, nData, publicKeyData) = try getTernaryParams()

        var n = try ScriptNumber(nData, minimal: config.contains(.minimalData))
        guard n.size <= 4 else {
            // - If n is larger than 4 bytes, the script MUST fail and terminate immediately.
            throw ScriptError.invalidCheckSigAddArgument
        }

        try checkSigSchnorr(sig, publicKeyData, adding: true)

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

    /// The input is hashed twice: first with SHA-256 and then with RIPEMD-160.
    mutating func opHash160() throws {
        let first = try getUnaryParam()
        stack.append(Data(Hash160.hash(data: first)))
    }

    /// The input is hashed twice with SHA-256.
    mutating func opHash256() throws {
        let first = try getUnaryParam()
        stack.append(Data(Hash256.hash(data: first)))
    }

    /// The input is hashed using RIPEMD-160.
    mutating func opRIPEMD160() throws {
        let first = try getUnaryParam()
        stack.append(Data(RIPEMD160.hash(data: first)))
    }

    /// The input is hashed using SHA-1.
    mutating func opSHA1() throws {
        let first = try getUnaryParam()
        stack.append(Data(SHA1.hash(data: first)))
    }

    /// The input is hashed using SHA-256.
    mutating func opSHA256() throws {
        let first = try getUnaryParam()
        stack.append(Data(SHA256.hash(data: first)))
    }

    private mutating func getCheckMultiSigParams() throws -> (Int, [Data], Int, [Data]) {
        guard stack.count > 4 else {
            throw ScriptError.missingMultiSigArgument
        }
        let n = try ScriptNumber(stack.removeLast(), minimal: config.contains(.minimalData)).value
        let publicKeys = Array(stack.suffix(n).reversed())
        stack.removeLast(n)
        let m = try ScriptNumber(stack.removeLast(), minimal: config.contains(.minimalData)).value
        let sigs = Array(stack.suffix(m).reversed())
        stack.removeLast(m)
        guard stack.count > 0 else {
            throw ScriptError.missingDummyValue
        }
        let dummyValue = stack.removeLast()
        if config.contains(.nullDummy), dummyValue.count > 0 {
            throw ScriptError.dummyValueNotNull
        }
        return (n, publicKeys, m, sigs)
    }

    private func checkSigECDSA(_ sig: Data, _ publicKeyData: Data, scriptCode: Data) throws -> Bool {
        try checkPublicKey(publicKeyData, scriptVersion: sigVersion, scriptConfig: config)
        try checkSignature(sig, scriptConfig: config)

        guard !sig.isEmpty else { return false }

        let (signatureData, sighashType) = splitECDSASignature(sig)
        let sighash = if sigVersion == .base {
            transaction.signatureHash(sighashType: sighashType, inputIndex: inputIndex, prevout: prevout, scriptCode: scriptCode)
        } else /* if sigVersion == .witnessV0 */ {
            transaction.signatureHashSegwit(sighashType: sighashType, inputIndex: inputIndex, prevout: prevout, scriptCode: scriptCode)
        }
        if let publicKey = PublicKey(publicKeyData), let signature = Signature(signatureData, type: .ecdsa) {
            return signature.verify(messageHash: sighash, publicKey: publicKey)
        }
        return false
    }

    private mutating func checkSigSchnorr(_ sig: Data, _ publicKeyData: Data, adding: Bool = false) throws {

        guard let tapLeafHash = tapLeafHash, let keyVersion = keyVersion else { preconditionFailure() }

        // If the public key size is zero, the script MUST fail and terminate immediately.
        guard !publicKeyData.isEmpty else { throw ScriptError.emptyPublicKey }

        if !sig.isEmpty { try checkSigopBudget() }

        // publicKeyData.count == 32,
        // `PublicKey(xOnly:)` essentially checks that the signature length is 32 bytes
        if let publicKey = PublicKey(xOnly: publicKeyData), !(sig.isEmpty && adding) {

            // If the public key size is 32 bytes, it is considered to be a public key as described in BIP340:

            if sig.isEmpty, !adding { return }
            // If the signature is not the empty vector, the signature is validated against the public key (see the next subsection).

            let ext = TapscriptExtension(tapLeafHash: tapLeafHash, keyVersion: keyVersion, codesepPos: codeSeparatorPosition)
            let extendedSignature = try ExtendedSignature(schnorrData: sig)
            let sighash = transaction.signatureHashSchnorr(sighashType: extendedSignature.sighashType, inputIndex: inputIndex, prevouts: prevouts, tapscriptExtension: ext, sighashCache: &sighashCache)

            // Validation failure in this case immediately terminates script execution with failure.
            guard extendedSignature.signature.verify(messageHash: sighash, publicKey: publicKey) else {
                throw ScriptError.invalidSchnorrSignature
            }
            return
        }

        if sig.isEmpty, !adding {
            // The script execution fails when using empty signature with invalid public key.
            throw ScriptError.emptySchnorrSignature
        }

        // If the public key size is not zero and not 32 bytes, the public key is of an unknown public key type and no actual signature verification is applied. During script execution of signature opcodes they behave exactly as known public key types except that signature validation is considered to be successful.
        if config.contains(.discourageUpgradablePublicKeyType) {
            throw ScriptError.disallowsPublicKeyType
        }
    }
}

// TODO: Move this logic into Signature struct somehow.
private func checkSignature(_ extendedSignatureData: Data, scriptConfig: ScriptConfig) throws {
    // Empty signature. Not strictly DER encoded, but allowed to provide a
    // compact way to provide an invalid signature for use with CHECK(MULTI)SIG
    if extendedSignatureData.isEmpty { return }

    let signatureData = extendedSignatureData.dropLast()

    if scriptConfig.contains(.strictDER) || scriptConfig.contains(.lowS) || scriptConfig.contains(.strictEncoding) {
        guard let signature = Signature(signatureData, type: .ecdsa) else {
            fatalError()
        }
        guard signature.isEncodingValid else {
            throw ScriptError.invalidSignatureEncoding
        }
    }
    if scriptConfig.contains(.lowS) {
        guard let signature = Signature(signatureData, type: .ecdsa) else {
            fatalError()
        }
        guard signature.isLowS else {
            throw ScriptError.nonLowSSignature
        }
    }
    if scriptConfig.contains(.strictEncoding)  {

        // TODO: Initialize SighashType with byte value instead of Data but be careful to allow undefined values!
        guard let sighashTypeByte = extendedSignatureData.last, let sighashType = SighashType(Data([sighashTypeByte])) else {
            preconditionFailure()
        }
        guard sighashType.isDefined else {
            throw ScriptError.undefinedSighashType
        }
    }
}

private func checkPublicKey(_ publicKeyData: Data, scriptVersion: SigVersion, scriptConfig: ScriptConfig) throws {
    if scriptConfig.contains(.strictEncoding) {
        // TODO: This may actually be checking that the uncompressed key is valid (as we convert it to compressed)
        guard let _ = PublicKey(publicKeyData) else {
            throw ScriptError.invalidPublicKeyEncoding
        }
    }
    // Only compressed keys are accepted in segwit
    if scriptVersion == .witnessV0 && scriptConfig.contains(.witnessCompressedPublicKey) {
        guard let _ = PublicKey(compressed: publicKeyData) else {
            throw ScriptError.invalidPublicKeyEncoding
        }
    }
}

private func splitECDSASignature(_ extendedSignature: Data) -> (Data, SighashType) {
    precondition(!extendedSignature.isEmpty)
    let signature = extendedSignature.dropLast()
    let sighashTypeData = extendedSignature.dropFirst(extendedSignature.count - 1)
    guard let sighashType = SighashType(sighashTypeData) else {
        preconditionFailure()
    }
    return (signature, sighashType)
}
