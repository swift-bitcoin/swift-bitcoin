import Foundation

extension ScriptContext {

    /// [BIP65](https://github.com/bitcoin/bips/blob/master/bip-0065.mediawiki)
    mutating func opCheckLockTimeVerify() throws {
        let first = try getUnaryParam(keep: true)
        let locktime64 = try ScriptNumber(first, extendedLength: true, minimal: config.contains(.minimalData)).value

        guard
            first.count < 6,
            locktime64 >= 0,
            locktime64 <= UInt32.max
        else { throw ScriptError.invalidLockTimeArgument }

        let locktime = TransactionLocktime(locktime64)

        if let blockHeight = locktime.blockHeight, let txBlockHeight = transaction.locktime.blockHeight {
            if blockHeight > txBlockHeight {
                throw ScriptError.lockTimeHeightEarly
            }
        } else if let seconds = locktime.secondsSince1970, let txSeconds = transaction.locktime.secondsSince1970 {
            if seconds > txSeconds {
                throw ScriptError.lockTimeSecondsEarly
            }
        } else {
            throw ScriptError.invalidLockTime
        }

        if transaction.inputs[inputIndex].sequence == .final { throw ScriptError.inputSequenceFinal }
    }

    /// [BIP112](https://github.com/bitcoin/bips/blob/master/bip-0112.mediawiki)
    mutating func opCheckSequenceVerify() throws {
        let first = try getUnaryParam(keep: true)
        let sequence64 = try ScriptNumber(first, extendedLength: true, minimal: config.contains(.minimalData)).value
        
        guard
            first.count < 6,
            sequence64 >= 0,
            sequence64 <= InputSequence.maxCSVArgument
        else { throw ScriptError.invalidSequenceArgument }
        
        let sequence = InputSequence(sequence64)
        if sequence.isLocktimeDisabled { return }
        
        if transaction.version == .v1 { throw ScriptError.minimumTransactionVersionRequired }
        
        let txSequence = transaction.inputs[inputIndex].sequence
        if txSequence.isLocktimeDisabled { throw ScriptError.sequenceLockTimeDisabled }
        
        if let locktimeBlocks = sequence.locktimeBlocks, let txLocktimeBlocks = txSequence.locktimeBlocks {
            if locktimeBlocks > txLocktimeBlocks {
                throw ScriptError.sequenceHeightEarly
            }
        } else if let seconds = sequence.locktimeSeconds, let txSeconds = txSequence.locktimeSeconds {
            if seconds > txSeconds {
                throw ScriptError.sequenceSecondsEarly
            }
        } else {
            throw ScriptError.invalidSequence
        }
    }
}
