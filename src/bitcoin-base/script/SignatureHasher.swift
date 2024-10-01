import Foundation
import BitcoinCrypto

/// A hash function which takes a transaction along with some context and produces a hash value for use with signature operations. The function only accepts a signature hash type which allows for commitments to different parts of the transaction.
public struct SignatureHash {

    public init(transaction: BitcoinTransaction, input inputIndex: Int, sigVersion: SigVersion = .base, prevout: TransactionOutput, scriptCode: Data? = .none, tapscriptExtension: TapscriptExtension? = .none, sighashType: SighashType = .all) {
        precondition(inputIndex < transaction.inputs.count)
        precondition(transaction.inputs.count == 1 || sigVersion == .base || sigVersion == .witnessV0)
        self.transaction = transaction
        self.inputIndex = inputIndex
        self.sigVersion = sigVersion
        self.prevouts = [prevout]
        self.scriptCode = scriptCode
        self.tapscriptExtension = tapscriptExtension
        self.sighashType = sighashType
    }

    public init(transaction: BitcoinTransaction, input inputIndex: Int, sigVersion: SigVersion = .base, prevouts: [TransactionOutput], scriptCode: Data? = .none, tapscriptExtension: TapscriptExtension? = .none, sighashType: SighashType? = Optional.none) {
        precondition(inputIndex < transaction.inputs.count)
        precondition(prevouts.count == transaction.inputs.count || (prevouts.count == 1 && (sigVersion == .base || sigVersion == .witnessV0)))
        self.transaction = transaction
        self.inputIndex = inputIndex
        self.sigVersion = sigVersion
        self.prevouts = prevouts
        self.scriptCode = scriptCode
        self.tapscriptExtension = tapscriptExtension
        self.sighashType = sighashType
    }

    public let transaction: BitcoinTransaction
    public private(set) var inputIndex: Int
    public private(set) var sigVersion: SigVersion
    public private(set) var prevouts: [TransactionOutput]
    public private(set) var scriptCode: Data?
    public private(set) var tapscriptExtension: TapscriptExtension?
    public private(set) var sighashType: SighashType?

    public var prevout: TransactionOutput {
        if prevouts.count == 1 { prevouts[0] } else { prevouts[inputIndex] }
    }

    public mutating func set(input inputIndex: Int, sigVersion: SigVersion? = .none, prevout: TransactionOutput) {
        if inputIndex != self.inputIndex {
            scriptCode = .none
            tapscriptExtension = .none
        }
        self.inputIndex = inputIndex
        self.prevouts = [prevout]
        if let sigVersion {
            self.sigVersion = sigVersion
        }
        precondition(inputIndex < transaction.inputs.count)
        precondition(transaction.inputs.count == 1 || self.sigVersion == .base || self.sigVersion == .witnessV0)
    }

    public mutating func set(input: Int, sigVersion: SigVersion? = .none, prevouts: [TransactionOutput]? = .none, sighashType: SighashType?) {
        set(input: input, sigVersion: sigVersion, prevouts: prevouts)
        self.sighashType = sighashType
        precondition(sigVersion == .witnessV1 || sighashType != Optional.none)
    }

    public mutating func set(input inputIndex: Int, sigVersion: SigVersion? = .none, prevouts newPrevouts: [TransactionOutput]? = .none) {
        if inputIndex != self.inputIndex {
            scriptCode = .none
            tapscriptExtension = .none
        }
        self.inputIndex = inputIndex
        if let newPrevouts {
            prevouts = newPrevouts
        }
        if let sigVersion {
            self.sigVersion = sigVersion
        }
        precondition(inputIndex < transaction.inputs.count)
        precondition(prevouts.count == transaction.inputs.count || (prevouts.count == 1 && (self.sigVersion == .base || self.sigVersion == .witnessV0)))

    }

    public var value: Data {
        switch sigVersion {
        case .base:
            return signatureHash
        case .witnessV0:
            return signatureHashSegwit
        case .witnessV1:
            var sighashCache = SighashCache()
            return signatureHashSchnorr(sighashCache: &sighashCache)
        }
    }

    /// Signature hash for legacy inputs.
    /// - Parameters:
    ///   - sighashType: Signature hash type.
    ///   - inputIndex: Transaction input index.
    ///   - prevout: Previous unspent transaction output corresponding to the transaction input being signed/verified.
    ///   - scriptCode: The executed script. For Pay-to-Script-Hash outputs it should correspond to the redeem script.
    /// - Returns: A hash value for use while either signing or verifying a transaction input.
    private var signatureHash: Data {
        guard let sighashType else { preconditionFailure() }

        if sighashType.isSingle && inputIndex >= transaction.outputs.count {
            // Note: The transaction that uses SIGHASH_SINGLE type of signature should not have more inputs than outputs. However if it does (because of the pre-existing implementation), it shall not be rejected, but instead for every "illegal" input (meaning: an input that has an index bigger than the maximum output index) the node should still verify it, though assuming the hash of 0000000000000000000000000000000000000000000000000000000000000001
            //
            // From [https://en.bitcoin.it/wiki/BIP_0143]:
            // In the original algorithm, a uint256 of 0x0000......0001 is committed if the input index for a SINGLE signature is greater than or equal to the number of outputs.
            return Data([0x01]) + Data(repeating: 0, count: 31)
        }
        return Data(Hash256.hash(data: signatureMessage))
    }

    /// Aka sigMsg. See https://en.bitcoin.it/wiki/OP_CHECKSIG
    private var signatureMessage: Data {
        guard let sighashType else { preconditionFailure() }

        let scriptCode = scriptCode ?? prevout.script.data

        var newIns = [TransactionInput]()
        if sighashType.isAnyCanPay {
            // Procedure for Hashtype SIGHASH_ANYONECANPAY
            // The txCopy input vector is resized to a length of one.
            // The current transaction input (with scriptPubKey modified to subScript) is set as the first and only member of this vector.
            newIns.append(.init(outpoint: transaction.inputs[inputIndex].outpoint, sequence: transaction.inputs[inputIndex].sequence, script: .init(scriptCode)))
        } else {
            transaction.inputs.enumerated().forEach { i, input in
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

            transaction.outputs.enumerated().forEach { i, out in
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
            newOuts = transaction.outputs
        }
        let txCopy = BitcoinTransaction(
            version: transaction.version,
            locktime: transaction.locktime,
            inputs: newIns,
            outputs: newOuts
        )
        return txCopy.data + sighashType.data32
    }

    /// BIP143
    private var signatureHashSegwit: Data {
        Data(Hash256.hash(data: signatureMessageSegwit))
    }

    /// BIP143: SegWit v0 signature message (sigMsg).
    private var signatureMessageSegwit: Data {
        guard let sighashType else { preconditionFailure() }

        let resolvedScriptCode: Data
        if prevout.script.isSegwit, prevout.script.witnessProgram.count == Hash160.Digest.byteCount {
            resolvedScriptCode = BitcoinScript.segwitPKHScriptCode(prevout.script.witnessProgram).data
            precondition(scriptCode == .none || scriptCode == scriptCode)
        } else if let scriptCode {
            resolvedScriptCode = scriptCode
        } else {
            preconditionFailure()
        }

        let amount = prevout.value
        //If the ANYONECANPAY flag is not set, hashPrevouts is the double SHA256 of the serialization of all input outpoints;
        // Otherwise, hashPrevouts is a uint256 of 0x0000......0000.
        var hashPrevouts: Data
        if sighashType.isAnyCanPay {
            hashPrevouts = Data(repeating: 0, count: 32)
        } else {
            let prevouts = transaction.inputs.reduce(Data()) { $0 + $1.outpoint.data }
            hashPrevouts = Data(Hash256.hash(data: prevouts))
        }

        // If none of the ANYONECANPAY, SINGLE, NONE sighash type is set, hashSequence is the double SHA256 of the serialization of nSequence of all inputs;
        // Otherwise, hashSequence is a uint256 of 0x0000......0000.
        let hashSequence: Data
        if !sighashType.isAnyCanPay && !sighashType.isSingle && !sighashType.isNone {
            let sequence = transaction.inputs.reduce(Data()) {
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
            let outsData = transaction.outputs.reduce(Data()) { $0 + $1.data }
            hashOuts = Data(Hash256.hash(data: outsData))
        } else if sighashType.isSingle && inputIndex < transaction.outputs.count {
            hashOuts = Data(Hash256.hash(data: transaction.outputs[inputIndex].data))
        } else {
            hashOuts = Data(repeating: 0, count: 32)
        }

        let outpointData = transaction.inputs[inputIndex].outpoint.data
        let scriptCodeData = resolvedScriptCode.varLenData
        let amountData = withUnsafeBytes(of: amount) { Data($0) }
        let sequenceData = transaction.inputs[inputIndex].sequence.data

        let remaindingData = sequenceData + hashOuts + transaction.locktime.data + sighashType.data32
        return transaction.version.data + hashPrevouts + hashSequence + outpointData + scriptCodeData + amountData + remaindingData
    }

    /// BIP341
    func signatureHashSchnorr(sighashCache: inout SighashCache) -> Data {
        var hasher = SHA256(tag: "TapSighash")
        hasher.update(data: signatureMessageSchnorr(sighashCache: &sighashCache))
        if let tapscriptExtension {
            hasher.update(data: tapscriptExtension.data)
        }
        return Data(hasher.finalize())
    }

    /// BIP341: SegWit v1 (Schnorr / TapRoot) signature message (sigMsg). More at https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki#common-signature-message .
    /// https://github.com/bitcoin/bitcoin/blob/58da1619be7ac13e686cb8bbfc2ab0f836eb3fa5/src/script/interpreter.cpp#L1477
    /// https://bitcoin.stackexchange.com/questions/115328/how-do-you-calculate-a-taproot-sighash
    func signatureMessageSchnorr(sighashCache: inout SighashCache) -> Data {

        let extFlag = UInt8(tapscriptExtension == .none ? 0 : 1)

        // For testing purposes we reset the hit count on each precomputed hash
        sighashCache.resetHits()

        // (the original witness stack has two or more witness elements, and the first byte of the last element is 0x50)
        let annex = transaction.inputs[inputIndex].witness?.taprootAnnex

        // Epoch:
        // epoch (0).
        let epochData = withUnsafeBytes(of: UInt8(0)) { Data($0) }

        // Control:
        // hash_type (1).
        let controlData = sighashType.data

        let sighashType = sighashType ?? .all

        precondition(!sighashType.isSingle || inputIndex < transaction.outputs.count, "For single hash type, the selected input needs to have a matching output.")

        // Transaction data:
        // nVersion (4): the nVersion of the transaction.
        var txData = transaction.version.data
        // nLockTime (4): the nLockTime of the transaction.
        txData.append(transaction.locktime.data)

        //If the hash_type & 0x80 does not equal SIGHASH_ANYONECANPAY:
        if !sighashType.isAnyCanPay {
            // sha_prevouts (32): the SHA256 of the serialization of all input outpoints.
            let shaPrevouts: Data
            if let cached = sighashCache.shaPrevouts {
                shaPrevouts = cached
                sighashCache.shaPrevoutsHit = true
            } else {
                let prevouts = transaction.inputs.reduce(Data()) { $0 + $1.outpoint.data }
                shaPrevouts = Data(SHA256.hash(data: prevouts))
                sighashCache.shaPrevouts = shaPrevouts
            }
            txData.append(shaPrevouts)

            // sha_amounts (32): the SHA256 of the serialization of all spent output amounts.
            let shaAmounts: Data
            if let cached = sighashCache.shaAmounts {
                shaAmounts = cached
                sighashCache.shaAmountsHit = true
            } else {
                let amounts = prevouts.reduce(Data()) { $0 + $1.valueData }
                shaAmounts = Data(SHA256.hash(data: amounts))
                sighashCache.shaAmounts = shaAmounts
            }
            txData.append(shaAmounts)

            // sha_scriptpubkeys (32): the SHA256 of all spent outputs' scriptPubKeys, serialized as script inside CTxOut.
            let shaScriptPubKeys: Data
            if let cached = sighashCache.shaScriptPubKeys {
                shaScriptPubKeys = cached
                sighashCache.shaScriptPubKeysHit = true
            } else {
                let scriptPubKeys = prevouts.reduce(Data()) { $0 + $1.script.prefixedData }
                shaScriptPubKeys = Data(SHA256.hash(data: scriptPubKeys))
                sighashCache.shaScriptPubKeys = shaScriptPubKeys
            }
            txData.append(shaScriptPubKeys)

            // sha_sequences (32): the SHA256 of the serialization of all input nSequence.
            let shaSequences: Data
            if let cached = sighashCache.shaSequences {
                shaSequences = cached
                sighashCache.shaSequencesHit = true
            } else {
                let sequences = transaction.inputs.reduce(Data()) { $0 + $1.sequence.data }
                shaSequences = Data(SHA256.hash(data: sequences))
                sighashCache.shaSequences = shaSequences
            }
            txData.append(shaSequences)
        }

        // If hash_type & 3 does not equal SIGHASH_NONE or SIGHASH_SINGLE:
        if !sighashType.isNone && !sighashType.isSingle {
            // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
            let shaOuts: Data
            if let cached = sighashCache.shaOuts {
                shaOuts = cached
                sighashCache.shaOutsHit = true
            } else {
                let outsData = transaction.outputs.reduce(Data()) { $0 + $1.data }
                shaOuts = Data(SHA256.hash(data: outsData))
                sighashCache.shaOuts = shaOuts
            }
            txData.append(shaOuts)
        }

        // Data about this input:
        // spend_type (1): equal to (ext_flag * 2) + annex_present, where annex_present is 0 if no annex is present, or 1 otherwise
        var inputData = Data()
        let spendType = (extFlag * 2) + (annex == .none ? 0 : 1)
        inputData.append(spendType)

        // If hash_type & 0x80 equals SIGHASH_ANYONECANPAY:
        if sighashType.isAnyCanPay {
            // outpoint (36): the COutPoint of this input (32-byte hash + 4-byte little-endian).
            let outpoint = transaction.inputs[inputIndex].outpoint.data
            inputData.append(outpoint)
            // amount (8): value of the previous output spent by this input.
            let amount = prevouts[inputIndex].valueData
            inputData.append(amount)
            // scriptPubKey (35): scriptPubKey of the previous output spent by this input, serialized as script inside CTxOut. Its size is always 35 bytes.
            let scriptPubKey = prevouts[inputIndex].script.prefixedData
            inputData.append(scriptPubKey)
            // nSequence (4): nSequence of this input.
            let sequence = transaction.inputs[inputIndex].sequence.data
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
            let shaSingleOutput = Data(SHA256.hash(data: transaction.outputs[inputIndex].data))
            outputData.append(shaSingleOutput)
        }

        let sigMsg = epochData + controlData + txData + inputData + outputData
        return sigMsg
    }
}
