import Foundation

/// Transaction checking.
extension Transaction {

    // MARK: - Instance Methods

    /// This function is called when validating a transaction and it's consensus critical.
    /// - Parameter weightLimit:usually `BitcoinBlockchain.ConsensusParams.maxBlockWeight` which equals 4,000,000.
    package func check(weightLimit: Int = Self.defaultWeightLimit) throws(ValidationError) {
        // Basic checks that don't depend on any context
        guard !ins.isEmpty else {
            throw .missingInputs
        }
        guard !outs.isEmpty else {
            throw .missingOutputs
        }

        // Size limits (this doesn't take the witness into account, as that hasn't been checked for malleability)
        guard weight <= weightLimit else {
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
        // While Consensus::CheckTxIns does check if all inputs of a tx are available, and UpdateCoins marks all inputs
        // of a tx as spent, it does not check if the tx has duplicate ins.
        // Failure to run this check will result in either a crash or an inflation bug, depending on the implementation of
        // the underlying coins database.
        var outpoints = Set<Outpoint>()
        for input in ins {
            outpoints.insert(input.outpoint)
        }
        guard ins.count == outpoints.count else {
            throw .duplicateInput
        }

        if isCoinbase && (ins[0].script.dataSize < 2 || ins[0].script.dataSize > 100) {
            throw .coinbaseLengthOutOfRange
        }
        if !isCoinbase {
            for input in ins {
                if input.outpoint == Outpoint.coinbase {
                    throw .missingOutpoint
                }
            }
        }
    }

    public func isFinal(blockHeight: Int, blockTime: Int) -> Bool {
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

    /// This is a duplicate of `BitcoinBlockchain.ConsensusParams.maxBlockWeight` which should equal 4,000,000.
    package static let defaultWeightLimit = 4_000_000
}
