import Foundation
import BitcoinCrypto
import BitcoinBase
/// Transaction checking.
extension Transaction {

    /// Runs basic checks that don't depend on any context.
    ///
    /// This function is called when checking a block and it's consensus critical. Also called when performing mempool pre-checks.
    ///
    /// Analog to Bitcoin Core's `CheckTransaction()`.
    func check() throws(ValidationError) {
        // Basic checks that don't depend on any context
        guard !ins.isEmpty else {
            throw .missingInputs
        }
        guard !outs.isEmpty else {
            throw .missingOutputs
        }

        // Size limits (this doesn't take the witness into account, as that hasn't been checked for malleability)
        let recalculatedWeight = dataSize(encoding: .noWitness) * Transaction.witnessScaleFactor
        // assert(recalculatedWeight == weight)
        guard recalculatedWeight <= Block.maxWeight else {
            throw .oversized
        }

        // Check for negative or overflow output values (see CVE-2010-5139)
        var valueOut: Amount = 0
        for out in outs {
            guard out.value >= 0 else {
                throw .negativeOutput
            }
            guard out.value <= Transaction.maxMoney else {
                throw .outputTooLarge
            }
            valueOut += out.value
            guard valueOut >= 0 && valueOut <= Transaction.maxMoney else {
                throw .totalOutputsTooLarge
            }
        }

        // Check for duplicate inputs (see CVE-2018-17144)
        // While Consensus::CheckTxIns does check if all inputs of a tx are available, and UpdateCoins marks all inputs of a tx as spent, it does not check if the tx has duplicate ins.
        // Failure to run this check will result in either a crash or an inflation bug, depending on the implementation of the underlying coins database.
        var outpoints = Set<Outpoint>()
        for txIn in ins {
            guard outpoints.insert(txIn.outpoint).inserted else {
                throw .duplicateInput
            }
        }

        if !isCoinbase {
            for input in ins {
                if input.outpoint == Outpoint.coinbase {
                }
            }
        }
        if isCoinbase {
            guard ins[0].script.dataSize >= 2 && ins[0].script.dataSize <= 100 else {
                throw .coinbaseLengthOutOfRange
            }
        } else {
            for txIn in ins {
                guard txIn.outpoint != Outpoint.coinbase else {
                    throw .missingOutpoint
                }
            }
        }
    }

    /// Check whether all inputs of this transaction are valid (no double spends and amounts).
    ///
    /// This function is called when checking a block and it's consensus critical. Also called when performing mempool pre-checks. Must be called after ``check()``.
    ///
    /// Analog to Bitcoin Core's `Consensus::CheckTxInputs()`.
    ///
    /// This does not modify the UTXO set. This does not check scripts and sigs.
    ///
    /// Precondition: must not be called on a coinbase transaction.
    func checkInputs(spendHeight: Int, coinbaseMaturity: Int, coins: [UnspentOutput]) async throws(ValidationError) {
        // bool Consensus::CheckTxInputs(const CTransaction& tx, TxValidationState& state, const CCoinsViewCache& inputs, int nSpendHeight, CAmount& txfee)

        precondition(!isCoinbase)

        let valueIn: Amount
        var valueInAcc = Amount(0)

        for coin in coins {
            guard !coin.isCoinbase || spendHeight - coin.height >= coinbaseMaturity else {
                throw .prematureCoinbaseSpend
            }
            valueInAcc += coin.out.value
            guard coin.out.value >= 0 && coin.out.value <= Transaction.maxMoney else {
                throw .inputValueOutOfRange
            }
            guard valueInAcc >= 0 && valueInAcc <= Transaction.maxMoney else {
                throw .inputValueOutOfRange
            }
        }
        valueIn = valueInAcc

        // This is guaranteed by calling Transaction.check() before this function.
        precondition(valueOut >= 0 && valueOut <= Transaction.maxMoney)

        guard valueIn >= valueOut else {
            throw .inputsValueBelowOutput
        }

        let fee = valueIn - valueOut
        guard fee >= 0 && fee <= Transaction.maxMoney else {
            throw .feeOutOfRange
        }
    }

    ///
    ///
    /// Analog to Bitcoin Core's `IsStandardTx()`.
    func isStandard() throws(PolicyViolation) {
        let permitBareMultisig = true // TODO: This is a startup option in Bitcoin Core.
        // TODO: Implement analog to Bitcoin Core's `isStandardTx()`
        // bool IsStandardTx(const CTransaction& tx, const std::optional<unsigned>& max_datacarrier_bytes, bool permit_bare_multisig, const CFeeRate& dust_relay_fee, std::string& reason)
        guard version >= Transaction.Version.minStandard && version <= Transaction.Version.maxStandard else {
            throw .transactionVersion
        }

        // Extremely large transactions with lots of inputs can cost the network almost as much to process as they cost the sender in fees, because computing signature hashes is O(ninputs*txsize). Limiting transactions to MAX_STANDARD_TX_WEIGHT mitigates CPU exhaustion attacks.
        guard weight <= Transaction.maxStandardWeight else {
            // reason = "tx-size"
            throw .transactionSize
        }

        for txIn in ins {
            // Biggest 'standard' txin involving only keys is a 15-of-15 P2SH multisig with compressed keys (remember the MAX_SCRIPT_ELEMENT_SIZE byte limit on redeemScript size). That works out to a (15*(33+1))+3=513 byte redeemScript, 513+1+15*(73+1)+3=1627 bytes of scriptSig, which we round off to 1650(MAX_STANDARD_SCRIPTSIG_SIZE) bytes for some minor future-proofing. That's also enough to spend a 20-of-20 CHECKMULTISIG scriptPubKey, though such a scriptPubKey is not considered standard.
            guard txIn.script.dataSize <= Script.maxStandardSize else {
                throw .inputScriptSize
            }
            guard txIn.script.isPushOnly else {
                throw .inputScriptNotPushOnly
            }
        }

        var datacarrierBytesLeft = Script.maxOpReturnRelay

        //var whichType = OutputType?.none
        for out in outs {
            guard let whichType = out.script.isStandard() else {
                throw .outputScriptNotStandard
            }

            if whichType == .nullData {
                let size = out.script.dataSize
                guard size <= datacarrierBytesLeft else {
                    throw .dataCarrierSize
                }
                datacarrierBytesLeft -= size
            } else if whichType == .multisig && !permitBareMultisig {
                // reason = "bare-multisig"
                throw .bareMultisig
            }
        }

        // Only MAX_DUST_OUTPUTS_PER_TX dust is permitted (on otherwise valid ephemeral dust)
        if getDust(dustRelayRate: Transaction.dustRelayFee).count > Transaction.maxDustOutputs {
            throw .tooManyDustOutputs
        }
    }

    /// Check if the transaction is over standard P2WSH resources limit: 3600bytes witnessScript size, 80bytes per witness stack element, 100 witness stack elements
    ///
    /// These limits are adequate for multisignatures up to n-of-100 using OP_CHECKSIG, OP_ADD, and OP_EQUAL.
    ///
    /// Also enforce a maximum stack item size limit and no annexes for tapscript spends.
    ///
    /// Called from `BlockchainService/mempoolAcceptPreChecks(:coins)`.
    ///
    /// Analog to Bitcoin Core's `IsWitnessStandard()`.
    func isWitnessStandard(prevouts: [TransactionOutput]) throws(PolicyViolation) {
        //bool IsWitnessStandard(const CTransaction& tx, const CCoinsViewCache& mapInputs)
        if isCoinbase {
            return // Coinbases are skipped
        }
        for (i, txIn) in ins.enumerated() {
            let prev = prevouts[i]
            // We don't care if witness for this input is empty, since it must not be bloated.
            // If the script is invalid without witness, it would be caught sooner or later during validation.
            if txIn.witness.stack.isEmpty {
                continue
            }
            // get the scriptPubKey corresponding to this input:
            var prevScript = prev.script;

            // witness stuffing detected
            if (prevScript.isPayToAnchor) {
                throw .witnessStuffing
            }

            var p2sh = false
            if prevScript.isPayToScriptHash {
                // If the scriptPubKey is P2SH, we try to extract the redeemScript casually by converting the scriptSig into a stack. We do not check IsPushOnly nor compare the hash as these will be done later anyway.
                // If the check fails at this stage, we know that this txid must be a bad one.
                var runtime = ScriptRuntime([], tx: self, input: i, prevouts: prevouts)
                do {
                    try runtime.run(txIn.script, stack: [], sigVersion: .base)
                } catch {
                    throw .p2shScriptFailure
                }
                guard let last = runtime.stack.last else {
                    throw .missingRedeemScript
                }
                guard let newPrevScript = try? Script(last) else {
                    throw .invalidRedeemScript
                }
                prevScript = newPrevScript
                p2sh = true
            }

            // Non-witness program must not be associated with any witness
            guard let (witnessVersion, witnessProgram) = prevScript.witnessVersionProgram else {
                throw .nonWitnessProgram
            }

            // Check P2WSH standard limits

            if witnessVersion == 0 && witnessProgram.count == SHA256.Digest.byteCount {
                let wstack = txIn.witness.stack
                if let last = wstack.last, last.count > Witness.maxP2WSHScriptSize {
                    throw .scriptSizeTooLarge
                }
                let sizeWitnessStack = max(wstack.count - 1, 0) // exclude witnessScript
                if sizeWitnessStack > Witness.maxP2WSHStackItems {
                    throw .tooManyWitnessStackItems
                }
                if sizeWitnessStack > 0 {
                    for j in 0..<sizeWitnessStack {
                        if wstack[j].count > Witness.maxP2WSHStackItemSize {
                            throw .witnessStackItemTooLarge
                        }
                    }
                }
            }

            // Check policy limits for Taproot spends:
            // - MAX_STANDARD_TAPSCRIPT_STACK_ITEM_SIZE limit for stack item size
            // - No annexes
            if witnessVersion == 1 && witnessProgram.count == PublicKey.xOnlyLength && !p2sh {
                // Taproot spend (non-P2SH-wrapped, version 1, witness program size 32; see BIP 341)
                var stack = txIn.witness.stack

                // Handle optional annex (last element starting with 0x50)
                if stack.count >= 2, let last = stack.last, let firstByte = last.first, firstByte == Witness.annexTag {
                    // stack.removeLast()
                    // Annexes are nonstandard as long as no semantics are defined for them.
                    throw .nonStandardTaprootAnnex
                }

                if stack.count >= 2 {
                    // Script path spend (2 or more stack elements after removing optional annex)
                    let controlBlock = stack.removeLast()
                    _ = stack.removeLast() // ignore script
                    if controlBlock.isEmpty { throw .emptyTaprootControlBlock } // Empty control block is invalid

                    if let first = controlBlock.first, (first & Witness.taprootLeafMask) == Witness.taprootLeafTapscript {
                        // Leaf version 0xc0 (aka Tapscript, see BIP 342)
                        for item in stack {
                            if item.count > Witness.maxTapscriptStackItemSize {
                                throw .tapscriptStackItemTooLarge
                            }
                        }
                    }
                } else if stack.count == 1 {
                    // Key path spend (1 stack element after removing optional annex)
                    // (no policy rules apply)
                } else {
                    // 0 stack elements; this is already invalid by consensus rules
                    throw .emptyWitnessStack
                }
            }
        }
    }

    /// Check transaction inputs.
    ///
    /// This does three things:
    ///  * Prevents mempool acceptance of spends of future
    ///    segwit versions we don't know how to validate
    ///  * Mitigates a potential denial-of-service attack with
    ///    P2SH scripts with a crazy number of expensive
    ///    CHECKSIG/CHECKMULTISIG operations.
    ///  * Prevents spends of unknown/irregular scriptPubKeys,
    ///    which mitigates potential denial-of-service attacks
    ///    involving expensive scripts and helps reserve them
    ///    as potential new upgrade hooks.
    ///
    /// Note that only the non-witness portion of the transaction is checked here.
    ///
    /// We also check the total number of non-witness sigops across the whole transaction, as per BIP54.
    func validateInputsStandardness(prevouts: [TransactionOutput]) throws(PolicyViolation) {
        // TxValidationState ValidateInputsStandardness(const CTransaction& tx, const CCoinsViewCache& mapInputs)

        if isCoinbase {
            return // Coinbases don't use vin normally
        }

        guard checkSigopsBIP54(prevouts: prevouts) else {
            // "bad-txns-nonstandard-inputs", "non-witness sigops exceed bip54 limit"
            throw .sigopsLimitExceeded
        }

        for (i, txIn) in ins.enumerated() {
            let prev = prevouts[i]
            let (whichType, _) = prev.script.solveOutputType()

            switch whichType {
            case .nonStandard:
                // "bad-txns-nonstandard-inputs", strprintf("input %u script unknown", i)
                throw .prevoutNonStandardOutputScript
            case .witnessUnknown:
                // WITNESS_UNKNOWN failures are typically also caught with a policy flag in the script interpreter, but it can be helpful to catch this type of NONSTANDARD transaction earlier in transaction validation.
                // "bad-txns-nonstandard-inputs", strprintf("input %u witness program is undefined", i)
                throw .prevoutWitnessProgramUndefined
            case .scriptHash:
                var runtime = ScriptRuntime([], tx: self, input: i, prevouts: prevouts)
                do {
                    try runtime.run(txIn.script, stack: [], sigVersion: .base)
                } catch {
                    throw .prevoutP2SHScriptFailure
                }
                guard let last = runtime.stack.last else {
                    throw .prevoutMissingRedeemScript
                }
                guard let subsSript = try? Script(last) else {
                    throw .prevoutInvalidRedeemScript
                }
                let sigops = subsSript.sigopCount(accurate: true)
                if (sigops > Script.maxP2SHSigops) {
                    // "bad-txns-nonstandard-inputs", strprintf("p2sh redeemscript sigops exceed limit (input %u: %u > %u)", i, sigop_count, MAX_P2SH_SIGOPS)
                    throw .prevoutRedeemScriptSigopsExceeded
                }
            default: break
            }
        }
    }

    func isFinal(blockHeight: Int, blockTime: Int) -> Bool {
        if locktime == .disabled { return true }

        if let txBlockHeight = locktime.blockHeight, txBlockHeight < blockHeight {
            return true
        }

        if let txBlockTime = locktime.secondsSince1970, txBlockTime < blockTime {
            return true
        }

        // Even if tx.nLockTime isn't satisfied by nBlockHeight/nBlockTime, a
        // transaction is still considered final if all inputs' nSequence ==
        // SEQUENCE_FINAL (0xffffffff), in which case nLockTime is ignored.
        //
        // Because of this behavior OP_CHECKLOCKTIMEVERIFY/CheckLockTime() will
        // also check that the spending input's nSequence != SEQUENCE_FINAL,
        // ensuring that an unsatisfied nLockTime value will actually cause
        // IsFinalTx() to return false here:
        return ins.allSatisfy { $0.sequence == .final }
    }

    /* @inline(__always) */ private func ceilDiv(_ a: UInt64, _ b: UInt64) -> UInt64 {
        precondition(b > 0)
        return (a &+ (b &- 1)) / b
    }

    /// Compute the fee for a given size `at_size` using this object's feerate.
    ///
    /// This effectively corresponds to evaluating (this->fee * at_size) / this->size, with the result rounded towards negative infinity (if RoundDown) or towards positive infinity  (if !RoundDown).
    ///
    /// Requires this->size > 0, at_size >= 0, and that the correct result fits in a int64_t. This is guaranteed to be the case when 0 <= at_size <= this->size.
    private func evaluateFee(_ feeRate: Amount, atSize: Int, roundDown: Bool) -> Amount {
        // Computes floor/ceil((feeRate * atSize) / size) with overflow safety.
        precondition(atSize >= 0)
        // CFeeRate::size — denominator for the rate. 1000 for sat/kvB in Core.
        let size: UInt64 = 1000

        // Fast path: guarantee (feeRate * atSize) fits in 64-bit.
        // 0x200000000 == 1 << 33
        if feeRate >= 0 && feeRate < Amount(1 << 33) {
            let a = UInt64(feeRate) // feeRate is non-negative in this branch
            let b = UInt64(atSize)
            if roundDown {
                let q = (a &* b) / size
                return Amount(q)
            } else {
                let q = ceilDiv(a &* b, size)
                return Amount(q)
            }
        } else {
            // Wide path: 128-bit product, then divide with rounding.
            // Use Swift’s full-width multiply and divide to avoid overflow.
            let a = UInt64(bitPattern: Int64(clamping: feeRate.magnitude)) // adjust if Amount isn't Int64
            let b = UInt64(atSize)

            let product = a.multipliedFullWidth(by: b) // (high: UInt64, low: UInt64)
            let (q, r) = size.dividingFullWidth(product) // quotient and remainder

            if roundDown {
                return Amount(q)
            } else {
                return Amount(q &+ (r == 0 ? 0 : 1))
            }
        }
    }

    private func evaluateFeeUp(_ feeRate: Amount, virtualBytes: Int) -> Amount {
        evaluateFee(feeRate, atSize: virtualBytes, roundDown: false)
    }

    private func getFee(_ feeRate: Amount, virtualBytes: Int) -> Amount {
    // CAmount CFeeRate::GetFee(int32_t virtual_bytes) const
        precondition(virtualBytes >= 0)
        if feeRate == 0 { return 0 }
        let fee = evaluateFeeUp(feeRate, virtualBytes: virtualBytes)
        // Mirror Core’s special case for negative rates.
        if fee == 0 && virtualBytes != 0 && feeRate < 0 {
            return -1
        }
        return fee
    }

    //CAmount GetDustThreshold(const CTxOut& txout, const CFeeRate& dustRelayFeeIn)
    private func getDustThreshold(out: TransactionOutput, dustRelayFeeIn: Amount) -> Amount {
        // "Dust" is defined in terms of dustRelayFee, which has units satoshis-per-kilobyte.
        // If you'd pay more in fees than the value of the output to spend something, then we consider it dust.
        // A typical spendable non-segwit txout is 34 bytes big, and will need a CTxIn of at least 148 bytes to spend:
        // so dust is a spendable txout less than 182*dustRelayFee/1000 (in satoshis).
        // 546 satoshis at the default rate of 3000 sat/kvB.
        // A typical spendable segwit P2WPKH txout is 31 bytes big, and will need a CTxIn of at least 67 bytes to spend:
        // so dust is a spendable txout less than 98*dustRelayFee/1000 (in satoshis).
        // 294 satoshis at the default rate of 3000 sat/kvB.
        if out.script.isUnspendable {
            return 0
        }

        var size = out.dataSize // uint64_t nSize{GetSerializeSize(txout)};

        // Note this computation is for spending a Segwit v0 P2WPKH output (a 33 bytes public key + an ECDSA signature). For Segwit v1 Taproot outputs the minimum satisfaction is lower (a single BIP340 signature) but this computation was  kept to not further reduce the dust level.
        // See discussion in https://github.com/bitcoin/bitcoin/pull/22779 for details.
        if out.script.isSegwit { // scriptPubKey.IsWitnessProgram(witnessversion, witnessprogram)) {
            // sum the sizes of the parts of a transaction input with 75% segwit discount applied to the script size.
            size += 32 + 4 + 1 + (107 / Transaction.witnessScaleFactor) + 4
        } else {
            size += 32 + 4 + 1 + 107 + 4 // the 148 mentioned above
        }

        return getFee(dustRelayFeeIn, virtualBytes: size)
    }


    private func isDust(out: TransactionOutput, dustRelayFeeIn: Amount) -> Bool {
        // bool IsDust(const CTxOut& txout, const CFeeRate& dustRelayFeeIn)
        out.value < getDustThreshold(out: out, dustRelayFeeIn: dustRelayFeeIn)
    }

    private func getDust(dustRelayRate: Amount) -> [Int] {
        // std::vector<uint32_t> GetDust(const CTransaction& tx, CFeeRate dust_relay_rate)
        var dustOutputs = [Int]()
        for (i, out) in outs.enumerated() {
            if isDust(out: out, dustRelayFeeIn: dustRelayRate) {
                dustOutputs.append(i)
            }
        }
        return dustOutputs
    }

    /// Check the total number of non-witness sigops across the whole transaction, as per BIP54.
    private func checkSigopsBIP54(prevouts: [TransactionOutput]) -> Bool {


        assert(!isCoinbase)

        var sigops = 0
        for (i, txIn) in ins.enumerated() {
            let prev = prevouts[i]

            // Unlike the existing block wide sigop limit which counts sigops present in the block itself (including the scriptPubKey which is not executed until spending later), BIP54 counts sigops in the block where they are potentially executed (only).
            // This means sigops in the spent scriptPubKey count toward the limit.
            // `accurate` means correctly accounting sigops for CHECKMULTISIGs(VERIFY) with 16 pubkeys or fewer. This method of accounting was introduced by BIP16, and BIP54 reuses it.
            // The sigopCount() call on the previous scriptPubKey counts both bare and P2SH sigops.
            sigops += txIn.script.sigopCount(accurate: true)
            sigops += prev.script.sigopCount(inputScript: txIn.script)

            guard sigops <= Script.maxTransactionLegacySigops else {
                return false
            }
        }
        return true
    }
}

public enum PolicyViolation: Swift.Error {

    // Transaction.isStandard

    case transactionVersion
    case transactionSize
    case inputScriptSize
    case inputScriptNotPushOnly
    case outputScriptNotStandard
    case dataCarrierSize
    case bareMultisig
    case tooManyDustOutputs

    // Transaction.isWitnessStandard

    case witnessStuffing
    case p2shScriptFailure
    case missingRedeemScript
    case invalidRedeemScript
    case nonWitnessProgram
    case scriptSizeTooLarge
    case tooManyWitnessStackItems
    case witnessStackItemTooLarge
    case nonStandardTaprootAnnex
    case emptyTaprootControlBlock
    case tapscriptStackItemTooLarge
    case emptyWitnessStack

    // validateInputsStandardness
    case sigopsLimitExceeded
    case prevoutNonStandardOutputScript
    case prevoutWitnessProgramUndefined
    case prevoutP2SHScriptFailure
    case prevoutMissingRedeemScript
    case prevoutInvalidRedeemScript
    case prevoutRedeemScriptSigopsExceeded
}
