import Foundation
import BitcoinCrypto

extension SignatureMessage {

    /// BIP341: SegWit v1 (Schnorr / TapRoot) signature message (sigMsg). More at https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki#common-signature-message .
    /// https://github.com/bitcoin/bitcoin/blob/58da1619be7ac13e686cb8bbfc2ab0f836eb3fa5/src/script/interpreter.cpp#L1477
    /// https://bitcoin.stackexchange.com/questions/115328/how-do-you-calculate-a-taproot-sighash
    struct Taproot: Equatable, Sendable {

        private init() { fatalError() }

        let data: Data
    }
}

extension SignatureMessage.Taproot {
    init(tx: Transaction, input inputIndex: Int, sighashType: SighashType?, prevouts: [TransactionOutput], tapscriptExtension: TapscriptExtension? = nil, sighashCache: inout Cache) {

        let extFlag = UInt8(tapscriptExtension == nil ? 0 : 1)

        // For testing purposes we reset the hit count on each precomputed hash
        sighashCache.resetHits()

        // (the original witness stack has two or more witness elements, and the first byte of the last element is 0x50)
        let annex = tx.ins[inputIndex].witness.taprootAnnex

        // Epoch:
        // epoch (0).
        let epochData = withUnsafeBytes(of: UInt8(0)) { Data($0) }

        // Control:
        // hash_type (1).
        let controlData = sighashType.data

        let sighashType = sighashType ?? .all

        precondition(!sighashType.isSingle || inputIndex < tx.outs.count, "For single hash type, the selected input needs to have a matching out.")

        // Transaction data:
        // nVersion (4): the nVersion of the tx.
        var txData = tx.version.binaryData
        // nLockTime (4): the nLockTime of the tx.
        txData.append(tx.locktime.binaryData)

        //If the hash_type & 0x80 does not equal SIGHASH_ANYONECANPAY:
        if !sighashType.isAnyCanPay {
            // sha_prevouts (32): the SHA256 of the serialization of all input outpoints.
            let shaPrevouts: Data
            if let cached = sighashCache.shaPrevouts {
                shaPrevouts = cached
                sighashCache.shaPrevoutsHit = true
            } else {
                let prevouts = tx.ins.reduce(Data()) { $0 + $1.outpoint.binaryData }
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
                let scriptPubKeys = prevouts.reduce(Data()) { $0 + $1.script.dataPrefixed }
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
                let sequences = tx.ins.reduce(Data()) { $0 + $1.sequence.binaryData }
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
                let outsData = tx.outs.reduce(Data()) { $0 + $1.binaryData }
                shaOuts = Data(SHA256.hash(data: outsData))
                sighashCache.shaOuts = shaOuts
            }
            txData.append(shaOuts)
        }

        // Data about this input:
        // spend_type (1): equal to (ext_flag * 2) + annex_present, where annex_present is 0 if no annex is present, or 1 otherwise
        var inputData = Data()
        let spendType = (extFlag * 2) + (annex == nil ? 0 : 1)
        inputData.append(spendType)

        // If hash_type & 0x80 equals SIGHASH_ANYONECANPAY:
        if sighashType.isAnyCanPay {
            // outpoint (36): the COutPoint of this input (32-byte hash + 4-byte little-endian).
            let outpoint = tx.ins[inputIndex].outpoint.binaryData
            inputData.append(outpoint)
            // amount (8): value of the previous output spent by this input.
            let amount = prevouts[inputIndex].valueData
            inputData.append(amount)
            // scriptPubKey (35): scriptPubKey of the previous output spent by this input, serialized as script inside CTxOut. Its size is always 35 bytes.
            let scriptPubKey = prevouts[inputIndex].script.dataPrefixed
            inputData.append(scriptPubKey)
            // nSequence (4): nSequence of this input.
            let sequence = tx.ins[inputIndex].sequence.binaryData
            inputData.append(sequence)
        } else { // If hash_type & 0x80 does not equal SIGHASH_ANYONECANPAY:
            // input_index (4): index of this input in the transaction input vector. Index of the first input is 0.
            let inputIndexData = withUnsafeBytes(of: UInt32(inputIndex)) { Data($0) }
            inputData.append(inputIndexData)
        }
        // If an annex is present (the lowest bit of spend_type is set):
        if let annex {
            // sha_annex (32): the SHA256 of (compact_size(size of annex) || annex), where annex includes the mandatory 0x50 prefix.
            // TODO: Review and make sure it includes the varInt prefix (length)
            let shaAnnex = Data(SHA256.hash(data: annex))
            inputData.append(shaAnnex)
        }

        // Data about this output:
        // If hash_type & 3 equals SIGHASH_SINGLE:
        var outData = Data()
        if sighashType.isSingle {
            //sha_single_output (32): the SHA256 of the corresponding output in CTxOut format.
            let shaSingleOutput = Data(SHA256.hash(data: tx.outs[inputIndex].binaryData))
            outData.append(shaSingleOutput)
        }

        data = epochData + controlData + txData + inputData + outData
    }
}
