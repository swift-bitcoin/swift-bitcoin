import Foundation

/// Transaction checking.
extension BitcoinTransaction {

    // MARK: - Computed Properties

    private var valueOut: BitcoinAmount {
        outputs.reduce(0) { $0 + $1.value }
    }
    
    // MARK: - Instance Methods

    /// This function is called when validating a transaction and it's consensus critical.
    func check() throws {
        // Basic checks that don't depend on any context
        guard !inputs.isEmpty else {
            throw TransactionError.noInputs
        }
        guard !outputs.isEmpty else {
            throw TransactionError.noOutputs
        }

        // Size limits (this doesn't take the witness into account, as that hasn't been checked for malleability)
        guard weight <= Self.maxBlockWeight else {
            throw TransactionError.oversized
        }

        // Check for negative or overflow output values (see CVE-2010-5139)
        var valueOut: BitcoinAmount = 0
        for output in outputs {
            guard output.value >= 0 else {
                throw TransactionError.negativeOutput
            }
            guard output.value <= Self.maxMoney else {
                throw TransactionError.outputTooLarge
            }
            valueOut += output.value
            guard valueOut >= 0 && valueOut <= Self.maxMoney else {
                throw TransactionError.totalOutputsTooLarge
            }
        }

        // Check for duplicate inputs (see CVE-2018-17144)
        // While Consensus::CheckTxInputs does check if all inputs of a tx are available, and UpdateCoins marks all inputs
        // of a tx as spent, it does not check if the tx has duplicate inputs.
        // Failure to run this check will result in either a crash or an inflation bug, depending on the implementation of
        // the underlying coins database.
        var outpoints = Set<TransactionOutpoint>()
        for input in inputs {
            outpoints.insert(input.outpoint)
        }
        guard inputs.count == outpoints.count else {
            throw TransactionError.duplicateInput
        }

        if isCoinbase && (inputs[0].script.size < 2 || inputs[0].script.size > 100) {
            throw TransactionError.coinbaseLengthOutOfRange
        }
        if !isCoinbase {
            for input in inputs {
                if input.outpoint == TransactionOutpoint.coinbase {
                    throw TransactionError.missingOutpoint
                }
            }
        }
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``Transaction.check()``.
    func checkInputs(coins: [TransactionOutpoint : UnspentOutput], spendHeight: Int) throws {
        // are the actual inputs available?
        if !isCoinbase {
            for outpoint in inputs.map(\.outpoint) {
                guard coins[outpoint] != .none else {
                    throw TransactionError.inputMissingOrSpent
                }
            }
        }

        var valueIn = BitcoinAmount(0)
        for input in inputs {
            let outpoint = input.outpoint
            guard let coin = coins[outpoint] else {
                preconditionFailure()
            }
            if coin.isCoinbase && spendHeight - coin.height < Self.coinbaseMaturity {
                throw TransactionError.prematureCoinbaseSpend
            }
            valueIn += coin.output.value
            guard coin.output.value >= 0 && coin.output.value <= Self.maxMoney,
                  valueIn >= 0 && valueIn <= Self.maxMoney
            else {
                throw TransactionError.inputValuesOutOfRange
            }
        }

        // This is guaranteed by calling Transaction.check() before this function.
        precondition(valueOut >= 0 && valueOut <= Self.maxMoney)

        guard valueIn >= valueOut else {
            throw TransactionError.inputsValueBelowOutput
        }

        let fee = valueIn - valueOut
        guard fee >= 0 && fee <= Self.maxMoney else {
            throw TransactionError.feeOutOfRange
        }
    }

    func isFinal(blockHeight: Int?, blockTime: Int?) -> Bool {
        precondition((blockHeight == .none && blockTime != .none) || (blockHeight != .none && blockTime == .none))
        if locktime == .disabled { return true }

        if let blockHeight, let txBlockHeight = locktime.blockHeight, txBlockHeight < blockHeight {
            return true
        } else if let blockTime, let txBlockTime = locktime.secondsSince1970, txBlockTime < blockTime {
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
        return inputs.allSatisfy { $0.sequence == .final }
    }

    /// BIP68 - Untested - Entrypoint 1.
    func checkSequenceLocks(verifyLockTimeSequence: Bool, coins: [TransactionOutpoint : UnspentOutput], chainTip: Int, previousBlockMedianTimePast: Int) throws {
        // CheckSequenceLocks() uses chainActive.Height()+1 to evaluate
        // height based locks because when SequenceLocks() is called within
        // ConnectBlock(), the height of the block *being*
        // evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the
        // *next* block, we need to use one more than chainActive.Height()
        let nextBlockHeight = chainTip + 1
        var heights = [Int]()
        // pcoinsTip contains the UTXO set for chainActive.Tip()
        for input in inputs {
            guard let coin = coins[input.outpoint] else {
                preconditionFailure()
            }
            if coin.height == 0x7FFFFFFF /* MEMPOOL_HEIGHT */ {
                // Assume all mempool transaction confirm in the next block
                heights.append(nextBlockHeight)
            } else {
                heights.append(coin.height)
            }
        }
        let lockPair = calculateSequenceLocks(verifyLockTimeSequence: verifyLockTimeSequence, previousHeights: &heights, blockHeight: nextBlockHeight)
        try evaluateSequenceLocks(blockHeight: nextBlockHeight, previousBlockMedianTimePast: previousBlockMedianTimePast, lockPair: lockPair)
    }

    /// BIP68 - Untested. Entrypoint 2.
    func sequenceLocks(verifyLockTimeSequence: Bool, previousHeights: inout [Int], blockHeight: Int, previousBlockMedianTimePast: Int) throws {
        try evaluateSequenceLocks(blockHeight: blockHeight, previousBlockMedianTimePast: previousBlockMedianTimePast, lockPair: calculateSequenceLocks(verifyLockTimeSequence: verifyLockTimeSequence, previousHeights: &previousHeights, blockHeight: blockHeight))
    }

    /// BIP68 - Untested
    /// Calculates the block height and previous block's median time past at
    /// which the transaction will be considered final in the context of BIP 68.
    /// Also removes from the vector of input heights any entries which did not
    /// correspond to sequence locked inputs as they do not affect the calculation.
    /// Called from ``Transaction.sequenceLocks()``.
    func calculateSequenceLocks(verifyLockTimeSequence: Bool, previousHeights: inout [Int], blockHeight: Int) -> (Int, Int) {

        precondition(previousHeights.count == inputs.count);

        // Will be set to the equivalent height- and time-based nLockTime
        // values that would be necessary to satisfy all relative lock-
        // time constraints given our view of block chain history.
        // The semantics of nLockTime are the last invalid height/time, so
        // use -1 to have the effect of any height or time being valid.
        var minHeight = -1;
        var minTime = -1;

        // tx.nVersion is signed integer so requires cast to unsigned otherwise
        // we would be doing a signed comparison and half the range of nVersion
        // wouldn't support BIP68.
        let enforceBIP68 = version >= .v2 && verifyLockTimeSequence

        // Do not enforce sequence numbers as a relative lock time
        // unless we have been instructed to
        guard enforceBIP68 else { return (minHeight, minTime) }

        for inputIndex in inputs.indices {
            let input = inputs[inputIndex]

            // Sequence numbers with the most significant bit set are not
            // treated as relative lock-times, nor are they given any
            // consensus-enforced meaning at this point.
            if input.sequence.isLocktimeDisabled {
                // The height of this input is not relevant for sequence locks
                previousHeights[inputIndex] = 0
                continue
            }

            let coinHeight = previousHeights[inputIndex]

            if let locktimeSeconds = input.sequence.locktimeSeconds {
                // NOTE: Subtract 1 to maintain nLockTime semantics
                // BIP68 relative lock times have the semantics of calculating
                // the first block or time at which the transaction would be
                // valid. When calculating the effective block time or height
                // for the entire transaction, we switch to using the
                // semantics of nLockTime which is the last invalid block
                // time or height.  Thus we subtract 1 from the calculated
                // time or height.
                //
                // Time-based relative lock-times are measured from the
                // smallest allowed timestamp of the block containing the
                // txout being spent, which is the median time past of the
                // block prior.
                let coinTime = 0 // TODO: Retrieve the block previous to the coin height `blockHeight.GetAncestor(std::max(nCoinHeight-1, 0))->GetMedianTimePast()`
                minTime = max(minTime, coinTime + locktimeSeconds - 1)
            } else if let locktimeBlocks = input.sequence.locktimeBlocks {
                minHeight = max(minHeight, coinHeight + locktimeBlocks - 1)
            }
        }
        return (minHeight, minTime)
    }

    /// BIP68 - Untested. Called by ``Transaction.checkSequenceLocks()`` and ``Transaction.sequenceLocks()``.
    func evaluateSequenceLocks(blockHeight: Int, previousBlockMedianTimePast: Int, lockPair: (Int, Int)) throws {
        if lockPair.0 >= blockHeight || lockPair.1 >= previousBlockMedianTimePast {
            throw TransactionError.futureLockTime
        }
    }
}
