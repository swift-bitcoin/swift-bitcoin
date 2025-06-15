import Foundation
import BitcoinCrypto

extension ScriptRuntime {

    /// The entire transaction's outputs, inputs, and script (from the most recently-executed `OP_CODESEPARATOR` to the end) are hashed. The signature used by `OP_CHECKSIG` must be a valid signature for this hash and public key. If it is, `1` is returned, `0` otherwise.
    mutating func opCheckSig() throws {
        let (sig, pubkeyData) = try getBinaryParams()

        if sigVersion == .witnessV1 {
            let result = try checkSigSchnorr(sig, pubkeyData)
            stack.append(ScriptBool(result).binaryData)
            return
        }

        let scriptCode = try sigVersion == .base ? getScriptCode(sigs: [sig]) : segwitScriptCode
        let result = try checkSigECDSA(sig, pubkeyData, scriptCode: scriptCode)
        if !result && config.contains(.nullFail) && !sig.isEmpty {
            throw ScriptError.signatureNotEmpty
        }
        stack.append(ScriptBool(result).binaryData)
    }

    /// Same as `OP_CHECKSIG`, but `OP_VERIFY` is executed afterward.
    mutating func opCheckSigVerify() throws {
        try opCheckSig()
        try opVerify()
    }

    /// Compares the first signature against each public key until it finds an ECDSA match. Starting with the subsequent public key, it compares the second signature against each remaining public key until it finds an ECDSA match. The process is repeated until all signatures have been checked or not enough public keys remain to produce a successful result. All signatures need to match a public key. Because public keys are not checked again if they fail any signature comparison, signatures must be placed in the `scriptSig` using the same order as their corresponding public keys were placed in the `scriptPubKey` or `redeemScript`. If all signatures are valid, `1` is returned, `0` otherwise. Due to a bug, one extra unused value is removed from the stack.
    mutating func opCheckMultiSig() throws {
        let (n, pubkeys, m, sigs) = try getCheckMultiSigParams()
        precondition(m <= n)
        precondition(pubkeys.count == n)
        precondition(sigs.count == m)

        guard n <= Script.maxMultiSigPubkeys else {
            throw ScriptError.maxPublicKeysExceeded
        }

        nonPushOps += n
        guard nonPushOps <= Script.maxOps else {
            throw ScriptError.operationsLimitExceeded
        }

        let scriptCode = try sigVersion == .base ? getScriptCode(sigs: sigs) : segwitScriptCode
        var keysCount = pubkeys.count
        var sigsCount = sigs.count
        var keyIndex = pubkeys.startIndex
        var sigIndex = sigs.startIndex
        var success = true
        while success && sigsCount > 0 {
            if try checkSigECDSA(sigs[sigIndex], pubkeys[keyIndex], scriptCode: scriptCode) {
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

        stack.append(ScriptBool(success).binaryData)
    }

    /// Same as `OP_CHECKMULTISIG`' but `OP_VERIFY` is executed afterward.
    mutating func opCheckMultiSigVerify() throws {
        try opCheckMultiSig()
        try opVerify()
    }


    /// BIP342: Three values are popped from the stack. The integer n is incremented by one and returned to the stack if the signature is valid for the public key and transaction. The integer n is returned to the stack unchanged if the signature is the empty vector (OP_0). In any other case, the script is invalid. This opcode is only available in tapscript.
    mutating func opCheckSigAdd() throws {
        // If fewer than 3 elements are on the stack, the script MUST fail and terminate immediately.
        let (sig, nData, pubkeyData) = try getTernaryParams()

        var n = try ScriptNumber(nData, minimal: config.contains(.minimalData))
        guard n.binarySize <= 4 else {
            // - If n is larger than 4 bytes, the script MUST fail and terminate immediately.
            throw ScriptError.invalidCheckSigAddArgument
        }

        let result = try checkSigSchnorr(sig, pubkeyData)

        // If the script did not fail and terminate before this step, regardless of the public key type:
        if !result {
            // If the signature is the empty vector:
            // For OP_CHECKSIGADD, a CScriptNum with value n is pushed onto the stack, and execution continues with the next opcode.
            stack.append(nData)
        } else {
            // If the signature is not the empty vector, the opcode is counted towards the sigops budget (see further).
            // For OP_CHECKSIGADD, a CScriptNum with value of n + 1 is pushed onto the stack.
            try n.add(.one)
            stack.append(n.binaryData)
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
        let pubkeys = Array(stack.suffix(n).reversed())
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
        return (n, pubkeys, m, sigs)
    }

    private func checkSigECDSA(_ sig: Data, _ pubkeyData: Data, scriptCode: Data) throws -> Bool {

        // Check public key
        if config.contains(.strictEncoding) {
            guard let _ = PublicKey(pubkeyData, skipCheck: true) else {
                throw ScriptError.invalidPublicKeyEncoding
            }
        }
        // Only compressed keys are accepted in segwit
        if sigVersion == .witnessV0 && config.contains(.witnessCompressedPubkey) {
            guard let _ = PublicKey(compressed: pubkeyData, skipCheck: true) else {
                throw ScriptError.invalidPublicKeyEncoding
            }
        }

        // Check signature
        // Empty signature. Not strictly DER encoded, but allowed to provide a
        // compact way to provide an invalid signature for use with CHECK(MULTI)SIG
        guard /* !sig.isEmpty, */
              let extendedSig = ECDSASignature.Extended(sig, skipCheck: true) else {
            return false
        }

        if config.contains(.strictDER) || config.contains(.lowS) || config.contains(.strictEncoding) {
            guard extendedSig.sig.isEncodingValid else {
                throw ScriptError.invalidSignatureEncoding
            }
        }
        if config.contains(.lowS) && !extendedSig.sig.isLowS {
            throw ScriptError.nonLowSSignature
        }

        let sighashType = extendedSig.sighashType

        if config.contains(.strictEncoding) && !sighashType.isDefined {
            throw ScriptError.undefinedSighashType
        }

        let sighash = if sigVersion == .base {
            SignatureHash(tx: tx, input: input, sighashType: sighashType, scriptCode: scriptCode).data
        } else {
            SignatureHash.Segwit(tx: tx, input: input, sighashType: sighashType, scriptCode: scriptCode, prevout: prevout).data
        }
        if let pubkey = PublicKey(pubkeyData) {
            return extendedSig.sig.verify(hash: sighash, pubkey: pubkey)
        }
        return false
    }

    private mutating func checkSigSchnorr(_ sig: Data, _ pubkeyData: Data) throws -> Bool {

        guard let tapLeafHash = tapLeafHash, let keyVersion = keyVersion else { preconditionFailure() }

        if !sig.isEmpty { try checkSigopBudget() }

        // If the public key size is zero, the script MUST fail and terminate immediately.
        guard !pubkeyData.isEmpty else { throw ScriptError.emptyPublicKey }

        // If the public key size is 32 bytes, it is considered to be a public key as described in BIP340:
        if let pubkey = PublicKey(xOnly: pubkeyData), !sig.isEmpty {

            let ext = TapscriptExtension(tapLeafHash: tapLeafHash, keyVersion: keyVersion, codesepPos: codeSeparatorPosition)
            let extendedSig = try SchnorrSignature.Extended(sig)
            let sighash = SignatureHash.Taproot(tx: tx, input: input, sighashType: extendedSig.sighashType, prevouts: prevouts, tapscriptExtension: ext, sighashCache: &sighashCache).data

            // Validation failure in this case immediately terminates script execution with failure.
            guard extendedSig.sig.verify(hash: sighash, pubkey: pubkey) else {
                throw ScriptError.invalidSchnorrSignature
            }
        } else if !sig.isEmpty {
            // If the public key size is not zero and not 32 bytes, the public key is of an unknown public key type and no actual signature verification is applied. During script execution of signature opcodes they behave exactly as known public key types except that signature validation is considered to be successful.
            if config.contains(.discourageUpgradablePubkeyType) {
                throw ScriptError.disallowsPublicKeyType
            }
        }
        return !sig.isEmpty
    }
}
