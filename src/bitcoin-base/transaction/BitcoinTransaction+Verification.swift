import Foundation
import BitcoinCrypto

private let taprootControlBaseSize = 33
private let taprootControlNodeSize = 32

/// Transaction inputs/scripts verification.
extension BitcoinTransaction {

    // MARK: - Instance Methods

    public func verifyScript(previousOutputs: [TransactionOutput], config: ScriptConfig = .standard) -> Bool {
        for i in inputs.indices {
            do {
                try verifyScript(inputIndex: i, previousOutputs: previousOutputs, config: config)
            } catch {
                print("\(error) \(error.localizedDescription)")
                return false
            }
        }
        return true
    }

    /// Initial simplified version of transaction verification that allows for script execution.
    func verifyScript(inputIndex: Int, previousOutputs: [TransactionOutput], config: ScriptConfig) throws {

        precondition(previousOutputs.count == inputs.count)

        let scriptSig = inputs[inputIndex].script
        let scriptPubKey = previousOutputs[inputIndex].script

        // BIP16
        let isPayToScriptHash = config.contains(.payToScriptHash) && scriptPubKey.isPayToScriptHash

        // BIP141
        let isNativeSegwit = config.contains(.witness) && scriptPubKey.isSegwit
        let isSegwit: Bool
        let witnessVersion: Int?
        let witnessProgram: Data?

        // The scriptSig must be exactly empty or validation fails.
        if isNativeSegwit && !scriptSig.isEmpty {
            throw ScriptError.scriptSigNotEmpty
        }

        // BIP62, BIP16
        if config.contains(.pushOnly) || isPayToScriptHash {
            try scriptSig.checkPushOnly()
        }

        if isNativeSegwit {
            isSegwit = true
            witnessVersion = scriptPubKey.witnessVersion
            witnessProgram = scriptPubKey.witnessProgram
        } else {
            // Execute scriptSig
            var context = ScriptContext(transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, config: config)
            try context.run(scriptSig)
            let stackTmp = context.stack // BIP16

            // scriptSig and scriptPubKey must be evaluated sequentially on the same stack rather than being simply concatenated (see CVE-2010-5141)
            try context.run(scriptPubKey, stack: stackTmp)
            if let last = context.stack.last, !ScriptBoolean(last).value {
                throw ScriptError.falseReturned
            }

            // BIP16
            if isPayToScriptHash {
                var stack = stackTmp
                guard let data = stack.popLast() else { preconditionFailure() }

                let redeemScript = BitcoinScript(data)

                // BIP141 - P2SH witness program
                if redeemScript.isSegwit {
                    isSegwit = true
                    witnessVersion = redeemScript.witnessVersion
                    witnessProgram = redeemScript.witnessProgram

                    // The scriptSig must be exactly a push of the BIP16 redeemScript or validation fails.
                    if !stack.isEmpty {
                        // We already checked that scriptSig was push only.
                        throw ScriptError.scriptSigTooManyPushes
                    }
                } else {
                    isSegwit = false
                    witnessVersion = .none
                    witnessProgram = .none

                    try context.run(redeemScript, stack: stack)
                    if let last = context.stack.last, !ScriptBoolean(last).value {
                        throw ScriptError.falseReturned
                    }
                }

            } else {
                isSegwit = false
                witnessVersion = .none
                witnessProgram = .none
            }

            if !isSegwit && config.contains(.cleanStack) && context.stack.count != 1 { // BIP62, BIP16
                throw ScriptError.uncleanStack
            }
        }

        // BIP141
        if isSegwit {
            guard let witnessVersion, let witnessProgram else { preconditionFailure() }
            if witnessVersion == 0 {
                try verifyWitness(inputIndex: inputIndex, witnessVersion: witnessVersion, witnessProgram: witnessProgram, previousOutputs: previousOutputs, config: config)
            } else if witnessVersion == 1 && witnessProgram.count == 32 && !isPayToScriptHash {
                // BIP341
                try verifyTaproot(inputIndex: inputIndex, witnessVersion: witnessVersion, witnessProgram: witnessProgram, previousOutputs: previousOutputs, config: config)
            } else if config.contains(.discourageUpgradableWitnessProgram) {
                throw ScriptError.disallowedWitnessVersion
            }
            // If the version byte is 2 to 16, no further interpretation of the witness program or witness stack happens
        }
    }

    private func verifyWitness(inputIndex: Int, witnessVersion: Int, witnessProgram: Data, previousOutputs: [TransactionOutput], config: ScriptConfig) throws {
        guard var stack = inputs[inputIndex].witness?.elements else { preconditionFailure() }

        if witnessProgram.count == 20 {
            // If the version byte is 0, and the witness program is 20 bytes: It is interpreted as a pay-to-witness-public-key-hash (P2WPKH) program.

            // BIP141: The witness must consist of exactly 2 items (≤ 520 bytes each). The first one a signature, and the second one a public key.
            // The `≤ 520` part is checked by ``Script.run()``.
            guard stack.count == 2 else {
                throw ScriptError.initialStackLimitExceeded
            }

            // For P2WPKH witness program, the scriptCode is 0x1976a914{20-byte-pubkey-hash}88ac.
            let witnessScript = BitcoinScript([
                .dup, .hash160, .pushBytes(witnessProgram), .equalVerify, .checkSig
            ], sigVersion: .witnessV0)

            var context = ScriptContext(transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, config: config)
            try context.run(witnessScript, stack: stack)

            // The verification must result in a single TRUE on the stack.
            guard context.stack.count == 1, let last = context.stack.last, ScriptBoolean(last).value else {
                throw ScriptError.falseReturned
            }
        } else if witnessProgram.count == 32 {
            // If the version byte is 0, and the witness program is 32 bytes: It is interpreted as a pay-to-witness-script-hash (P2WSH) program.

            // BIP141: The witnessScript (≤ 10,000 bytes) is popped off the initial witness stack.
            guard let witnessScriptRaw = stack.popLast() else {
                preconditionFailure()
            }
            // This check is repeated inside ``Script.run()``.
            if witnessScriptRaw.count > BitcoinScript.maxScriptSize {
                throw ScriptError.scriptSizeLimitExceeded
            }

            // SHA256 of the witnessScript must match the 32-byte witness program.
            guard Data(SHA256.hash(data: witnessScriptRaw)) == witnessProgram else {
                throw ScriptError.wrongWitnessScriptHash
            }

            var context = ScriptContext(transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, config: config)
            let witnessScript = BitcoinScript(witnessScriptRaw, sigVersion: .witnessV0)
            try context.run(witnessScript, stack: stack)

            // The script must not fail, and result in exactly a single TRUE on the stack.
            guard context.stack.count == 1, let last = context.stack.last, ScriptBoolean(last).value else {
                throw ScriptError.falseReturned
            }
        } else {
            // If the version byte is 0, but the witness program is neither 20 nor 32 bytes, the script must fail.
            throw ScriptError.witnessProgramWrongLength
        }
    }

    /// BIP341, BIP342
    private func verifyTaproot(inputIndex: Int, witnessVersion: Int, witnessProgram: Data, previousOutputs: [TransactionOutput], config: ScriptConfig) throws {

        guard let witness = inputs[inputIndex].witness else { preconditionFailure() }
        guard config.contains(.taproot) else { return }

        var stack = witness.elements
        // Fail if the witness stack has 0 elements.
        if stack.count == 0 { throw ScriptError.missingTaprootWitness }

        // In this case it is the key (aka taproot output key q)
        let outputKeyData = witnessProgram

        // this last element is called annex a and is removed from the witness stack
        if witness.taprootAnnex != .none { stack.removeLast() }

        // If there is exactly one element left in the witness stack, key path spending is used:
        if stack.count == 1 {
            let (signatureData, sighashType) = try SighashType.splitSchnorrSignature(stack[0])
            var cache = SighashCache() // TODO: Hold on to cache.
            let sighash = self.signatureHashSchnorr(sighashType: sighashType, inputIndex: inputIndex, previousOutputs: previousOutputs, tapscriptExtension: .none, sighashCache: &cache)
            guard let publicKey = PublicKey(xOnly: witnessProgram) else {
                fatalError()
            }
            guard let signature = Signature(signatureData, type: .schnorr) else {
                throw ScriptError.invalidSchnorrSignatureFormat
            }
            guard signature.verify(messageHash: sighash, publicKey: publicKey) else {
                throw ScriptError.invalidSchnorrSignature
            }
            return
        }

        // If there are at least two witness elements left, script path spending is used:
        // The last stack element is called the control block c
        let control = stack.removeLast()

        // control block c, and must have length 33 + 32m, for a value of m that is an integer between 0 and 128, inclusive. Fail if it does not have such a length.
        guard control.count >= taprootControlBaseSize && (control.count - taprootControlBaseSize) % taprootControlNodeSize == 0 && (control.count - taprootControlBaseSize) / taprootControlNodeSize <= 128 else {
            throw ScriptError.invalidTapscriptControlBlock
        }

        // Call the second-to-last stack element s, the script.
        // The script as defined in BIP341 (i.e., the penultimate witness stack element after removing the optional annex) is called the tapscript
        let tapscriptData = stack.removeLast()

        // Let p = c[1:33] and let P = lift_x(int(p)) where lift_x and [:] are defined as in BIP340. Fail if this point is not on the curve.
        // q is referred to as taproot output key and p as taproot internal key.
        let internalKeyData = control.dropFirst().prefix(PublicKey.xOnlyLength)

        // Fail if this point is not on the curve.
        guard let internalKey = PublicKey(xOnly: internalKeyData), internalKey.isPointOnCurve(useXOnly: true) else { throw ScriptError.invalidTaprootPublicKey }

        // Let v = c[0] & 0xfe and call it the leaf version
        let leafVersion = control[0] & 0xfe

        // Let k0 = hashTapLeaf(v || compact_size(size of s) || s); also call it the tapleaf hash.
        let tapLeafHash = Data(SHA256.hash(data: [leafVersion] + tapscriptData.varLenData, tag: "TapLeaf"))

        // Compute the Merkle root from the leaf and the provided path.
        let merkleRoot = computeMerkleRoot(controlBlock: control, tapLeafHash: tapLeafHash)

        let tweak = internalKey.tapTweak(merkleRoot: merkleRoot)

        // Verify that the output pubkey matches the tweaked internal pubkey, after correcting for parity.
        //let parity = (control[0] & 0x01) != 0
        let hasEvenY = (control[0] & 0x01) == 0
        let outputKey = PublicKey(xOnly: outputKeyData, hasEvenY: hasEvenY)! // TODO: Check if this could fail somehow when witness data contains an invalid public key.
        guard internalKey.checkTweak(tweak, outputKey: outputKey) else {
            throw ScriptError.invalidTaprootTweak
        }

        // BIP 342 Tapscript - https://github.com/bitcoin/bips/blob/master/bip-0342.mediawiki
        // The leaf version is 0xc0 (i.e. the first byte of the last witness element after removing the optional annex is 0xc0 or 0xc1), marking it as a tapscript spend.
        guard leafVersion == 0xc0 else {
            if config.contains(.discourageUpgradableTaprootVersion) {
                throw ScriptError.disallowedTaprootVersion
            }
            return
        }

        var context = ScriptContext(transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, config: config, tapLeafHash: tapLeafHash)
        let tapscript = BitcoinScript(tapscriptData, sigVersion: .witnessV1)
        try context.run(tapscript, stack: stack)
    }

    /// Signature hash for legacy inputs.
    /// - Parameters:
    ///   - sighashType: Signature hash type.
    ///   - inputIndex: Transaction input index.
    ///   - previousOutput: Previous unspent transaction output corresponding to the transaction input being signed/verified.
    ///   - scriptCode: The executed script. For Pay-to-Script-Hash outputs it should correspond to the redeem script.
    /// - Returns: A hash value for use while either signing or verifying a transaction input.
    public func signatureHash(sighashType: SighashType, inputIndex: Int, previousOutput: TransactionOutput, scriptCode: Data) -> Data {
        if sighashType.isSingle && inputIndex >= outputs.count {
            // Note: The transaction that uses SIGHASH_SINGLE type of signature should not have more inputs than outputs. However if it does (because of the pre-existing implementation), it shall not be rejected, but instead for every "illegal" input (meaning: an input that has an index bigger than the maximum output index) the node should still verify it, though assuming the hash of 0000000000000000000000000000000000000000000000000000000000000001
            //
            // From [https://en.bitcoin.it/wiki/BIP_0143]:
            // In the original algorithm, a uint256 of 0x0000......0001 is committed if the input index for a SINGLE signature is greater than or equal to the number of outputs.
            return Data([0x01]) + Data(repeating: 0, count: 31)
        }
        let sigMsg = signatureMessage(sighashType: sighashType, inputIndex: inputIndex, scriptCode: scriptCode)
        return Data(Hash256.hash(data: sigMsg))
    }

    /// Aka sigMsg. See https://en.bitcoin.it/wiki/OP_CHECKSIG
    func signatureMessage(sighashType: SighashType, inputIndex: Int, scriptCode: Data) -> Data {
        var newIns = [TransactionInput]()
        if sighashType.isAnyCanPay {
            // Procedure for Hashtype SIGHASH_ANYONECANPAY
            // The txCopy input vector is resized to a length of one.
            // The current transaction input (with scriptPubKey modified to subScript) is set as the first and only member of this vector.
            newIns.append(.init(outpoint: inputs[inputIndex].outpoint, sequence: inputs[inputIndex].sequence, script: .init(scriptCode)))
        } else {
            inputs.enumerated().forEach { i, input in
                newIns.append(.init(
                    outpoint: input.outpoint,
                    // SIGHASH_NONE | SIGHASH_SINGLE - All other txCopy inputs aside from the current input are set to have an nSequence index of zero.
                    sequence: i == inputIndex || (!sighashType.isNone && !sighashType.isSingle) ? input.sequence : .initial,
                    // The scripts for all transaction inputs in txCopy are set to empty scripts (exactly 1 byte 0x00)
                    // The script for the current transaction input in txCopy is set to subScript (lead in by its length as a var-integer encoded!)
                    script: i == inputIndex ? .init(scriptCode) : .empty
                ))
            }
        }
        var newOuts: [TransactionOutput]
        // Procedure for Hashtype SIGHASH_SINGLE

        if sighashType.isSingle {
            // The output of txCopy is resized to the size of the current input index+1.
            // All other txCopy outputs aside from the output that is the same as the current input index are set to a blank script and a value of (long) -1.
            newOuts = []

            outputs.enumerated().forEach { i, out in
                guard i <= inputIndex else {
                    return
                }
                if i == inputIndex {
                    newOuts.append(out)
                } else if i < inputIndex {
                    // Value is "long -1" which means UInt64(bitPattern: -1) aka UInt64.max
                    newOuts.append(.init(value: -1, script: BitcoinScript.empty))
                }
            }
        } else if sighashType.isNone {
            newOuts = []
        } else {
            newOuts = outputs
        }
        let txCopy = BitcoinTransaction(
            version: version,
            locktime: locktime,
            inputs: newIns,
            outputs: newOuts
        )
        return txCopy.data + sighashType.data32
    }

    /// BIP143
    func signatureHashSegwit(sighashType: SighashType, inputIndex: Int, previousOutput: TransactionOutput, scriptCode: Data) -> Data {
        Data(Hash256.hash(data: signatureMessageSegwit(sighashType: sighashType, inputIndex: inputIndex, scriptCode: scriptCode, amount: previousOutput.value)))
    }

    /// BIP143: SegWit v0 signature message (sigMsg).
    func signatureMessageSegwit(sighashType: SighashType, inputIndex: Int, scriptCode: Data, amount: BitcoinAmount) -> Data {
        //If the ANYONECANPAY flag is not set, hashPrevouts is the double SHA256 of the serialization of all input outpoints;
        // Otherwise, hashPrevouts is a uint256 of 0x0000......0000.
        var hashPrevouts: Data
        if sighashType.isAnyCanPay {
            hashPrevouts = Data(repeating: 0, count: 32)
        } else {
            let prevouts = inputs.reduce(Data()) { $0 + $1.outpoint.data }
            hashPrevouts = Data(Hash256.hash(data: prevouts))
        }

        // If none of the ANYONECANPAY, SINGLE, NONE sighash type is set, hashSequence is the double SHA256 of the serialization of nSequence of all inputs;
        // Otherwise, hashSequence is a uint256 of 0x0000......0000.
        let hashSequence: Data
        if !sighashType.isAnyCanPay && !sighashType.isSingle && !sighashType.isNone {
            let sequence = inputs.reduce(Data()) {
                $0 + $1.sequence.data
            }
            hashSequence = Data(Hash256.hash(data: sequence))
        } else {
            hashSequence = Data(repeating: 0, count: 32)
        }

        // If the sighash type is neither SINGLE nor NONE, hashOutputs is the double SHA256 of the serialization of all output amount (8-byte little endian) with scriptPubKey (serialized as scripts inside CTxOuts);
        // If sighash type is SINGLE and the input index is smaller than the number of outputs, hashOutputs is the double SHA256 of the output amount with scriptPubKey of the same index as the input;
        // Otherwise, hashOutputs is a uint256 of 0x0000......0000.[7]
        let hashOuts: Data
        if !sighashType.isSingle && !sighashType.isNone {
            let outsData = outputs.reduce(Data()) { $0 + $1.data }
            hashOuts = Data(Hash256.hash(data: outsData))
        } else if sighashType.isSingle && inputIndex < outputs.count {
            hashOuts = Data(Hash256.hash(data: outputs[inputIndex].data))
        } else {
            hashOuts = Data(repeating: 0, count: 32)
        }

        let outpointData = inputs[inputIndex].outpoint.data
        let scriptCodeData = scriptCode.varLenData
        let amountData = withUnsafeBytes(of: amount) { Data($0) }
        let sequenceData = inputs[inputIndex].sequence.data

        let remaindingData = sequenceData + hashOuts + locktime.data + sighashType.data32
        return version.data + hashPrevouts + hashSequence + outpointData + scriptCodeData + amountData + remaindingData
    }

    /// BIP341
    func signatureHashSchnorr(sighashType: SighashType?, inputIndex: Int, previousOutputs: [TransactionOutput], tapscriptExtension: TapscriptExtension? = .none) -> Data {
        var cache = SighashCache()
        return signatureHashSchnorr(sighashType: sighashType, inputIndex: inputIndex, previousOutputs: previousOutputs, tapscriptExtension: tapscriptExtension, sighashCache: &cache)
    }

    /// BIP341
    func signatureHashSchnorr(sighashType: SighashType?, inputIndex: Int, previousOutputs: [TransactionOutput], tapscriptExtension: TapscriptExtension? = .none, sighashCache: inout SighashCache) -> Data {
        var hasher = SHA256(tag: "TapSighash")
        hasher.update(data: signatureMessageSchnorr(sighashType: sighashType, extFlag: tapscriptExtension == .none ? 0 : 1, inputIndex: inputIndex, previousOutputs: previousOutputs, sighashCache: &sighashCache))
        if let tapscriptExtension {
            hasher.update(data: tapscriptExtension.data)
        }
        return Data(hasher.finalize())
    }

    /// BIP341: SegWit v1 (Schnorr / TapRoot) signature message (sigMsg). More at https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki#common-signature-message .
    /// https://github.com/bitcoin/bitcoin/blob/58da1619be7ac13e686cb8bbfc2ab0f836eb3fa5/src/script/interpreter.cpp#L1477
    /// https://bitcoin.stackexchange.com/questions/115328/how-do-you-calculate-a-taproot-sighash
    func signatureMessageSchnorr(sighashType: SighashType?, extFlag: UInt8 = 0, inputIndex: Int, previousOutputs: [TransactionOutput], sighashCache: inout SighashCache) -> Data {

        precondition(previousOutputs.count == inputs.count, "The corresponding (aligned) UTXO for each transaction input is required.")
        precondition(!sighashType.isSingle || inputIndex < outputs.count, "For single hash type, the selected input needs to have a matching output.")

        // (the original witness stack has two or more witness elements, and the first byte of the last element is 0x50)
        let annex = inputs[inputIndex].witness?.taprootAnnex

        // Epoch:
        // epoch (0).
        let epochData = withUnsafeBytes(of: UInt8(0)) { Data($0) }

        // Control:
        // hash_type (1).
        let controlData = sighashType.data

        // Transaction data:
        // nVersion (4): the nVersion of the transaction.
        var txData = version.data
        // nLockTime (4): the nLockTime of the transaction.
        txData.append(locktime.data)

        //If the hash_type & 0x80 does not equal SIGHASH_ANYONECANPAY:
        if !sighashType.isAnyCanPay {
            // sha_prevouts (32): the SHA256 of the serialization of all input outpoints.
            let shaPrevouts: Data
            if let cached = sighashCache.shaPrevouts {
                shaPrevouts = cached
            } else {
                let prevouts = inputs.reduce(Data()) { $0 + $1.outpoint.data }
                shaPrevouts = Data(SHA256.hash(data: prevouts))
                sighashCache.shaPrevouts = shaPrevouts
            }
            sighashCache.shaPrevoutsUsed = true
            txData.append(shaPrevouts)

            // sha_amounts (32): the SHA256 of the serialization of all spent output amounts.
            let shaAmounts: Data
            if let cached = sighashCache.shaAmounts {
                shaAmounts = cached
            } else {
                let amounts = previousOutputs.reduce(Data()) { $0 + $1.valueData }
                shaAmounts = Data(SHA256.hash(data: amounts))
                sighashCache.shaAmounts = shaAmounts
            }
            sighashCache.shaAmountsUsed = true
            txData.append(shaAmounts)

            // sha_scriptpubkeys (32): the SHA256 of all spent outputs' scriptPubKeys, serialized as script inside CTxOut.
            let shaScriptPubKeys: Data
            if let cached = sighashCache.shaScriptPubKeys {
                shaScriptPubKeys = cached
            } else {
                let scriptPubKeys = previousOutputs.reduce(Data()) { $0 + $1.script.prefixedData }
                shaScriptPubKeys = Data(SHA256.hash(data: scriptPubKeys))
                sighashCache.shaScriptPubKeys = shaScriptPubKeys
            }
            sighashCache.shaScriptPubKeysUsed = true
            txData.append(shaScriptPubKeys)

            // sha_sequences (32): the SHA256 of the serialization of all input nSequence.
            let shaSequences: Data
            if let cached = sighashCache.shaSequences {
                shaSequences = cached
            } else {
                let sequences = inputs.reduce(Data()) { $0 + $1.sequence.data }
                shaSequences = Data(SHA256.hash(data: sequences))
                sighashCache.shaSequences = shaSequences
            }
            sighashCache.shaSequencesUsed = true
            txData.append(shaSequences)
        } else {
            sighashCache.shaPrevoutsUsed = false
            sighashCache.shaAmountsUsed = false
            sighashCache.shaScriptPubKeysUsed = false
            sighashCache.shaSequencesUsed = false
        }

        // If hash_type & 3 does not equal SIGHASH_NONE or SIGHASH_SINGLE:
        if !sighashType.isNone && !sighashType.isSingle {
            // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
            let shaOuts: Data
            if let cached = sighashCache.shaOuts {
                shaOuts = cached
            } else {
                let outsData = outputs.reduce(Data()) { $0 + $1.data }
                shaOuts = Data(SHA256.hash(data: outsData))
                sighashCache.shaOuts = shaOuts
            }
            sighashCache.shaOutsUsed = true
            txData.append(shaOuts)
        } else {
            sighashCache.shaOutsUsed = false
        }

        // Data about this input:
        // spend_type (1): equal to (ext_flag * 2) + annex_present, where annex_present is 0 if no annex is present, or 1 otherwise
        var inputData = Data()
        let spendType = (extFlag * 2) + (annex == .none ? 0 : 1)
        inputData.append(spendType)

        // If hash_type & 0x80 equals SIGHASH_ANYONECANPAY:
        if sighashType.isAnyCanPay {
            // outpoint (36): the COutPoint of this input (32-byte hash + 4-byte little-endian).
            let outpoint = inputs[inputIndex].outpoint.data
            inputData.append(outpoint)
            // amount (8): value of the previous output spent by this input.
            let amount = previousOutputs[inputIndex].valueData
            inputData.append(amount)
            // scriptPubKey (35): scriptPubKey of the previous output spent by this input, serialized as script inside CTxOut. Its size is always 35 bytes.
            let scriptPubKey = previousOutputs[inputIndex].script.prefixedData
            inputData.append(scriptPubKey)
            // nSequence (4): nSequence of this input.
            let sequence = inputs[inputIndex].sequence.data
            inputData.append(sequence)
        } else { // If hash_type & 0x80 does not equal SIGHASH_ANYONECANPAY:
            // input_index (4): index of this input in the transaction input vector. Index of the first input is 0.
            let inputIndexData = withUnsafeBytes(of: UInt32(inputIndex)) { Data($0) }
            inputData.append(inputIndexData)
        }
        //If an annex is present (the lowest bit of spend_type is set):
        if let annex {
            //sha_annex (32): the SHA256 of (compact_size(size of annex) || annex), where annex includes the mandatory 0x50 prefix.
            // TODO: Review and make sure it includes the varInt prefix (length)
            let shaAnnex = Data(SHA256.hash(data: annex))
            inputData.append(shaAnnex)
        }

        //Data about this output:
        //If hash_type & 3 equals SIGHASH_SINGLE:
        var outputData = Data()
        if sighashType.isSingle {
            //sha_single_output (32): the SHA256 of the corresponding output in CTxOut format.
            let shaSingleOutput = Data(SHA256.hash(data: outputs[inputIndex].data))
            outputData.append(shaSingleOutput)
        }

        let sigMsg = epochData + controlData + txData + inputData + outputData
        return sigMsg
    }
}

private func computeMerkleRoot(controlBlock: Data, tapLeafHash: Data) -> Data {
    let pathLen = (controlBlock.count - taprootControlBaseSize) / taprootControlNodeSize
    var k = tapLeafHash
    for i in 0 ..< pathLen {
        let startIndex = controlBlock.startIndex.advanced(by: taprootControlBaseSize + taprootControlNodeSize * i)
        let endIndex = startIndex.advanced(by: taprootControlNodeSize)
        let node = controlBlock[startIndex ..< endIndex]
        let payload = k.lexicographicallyPrecedes(node) ? k + node : node + k
        k = Data(SHA256.hash(data: payload, tag: "TapBranch"))
    }
    return k
}
