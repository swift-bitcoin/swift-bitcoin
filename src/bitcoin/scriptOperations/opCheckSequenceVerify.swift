import Foundation

/// [BIP112](https://github.com/bitcoin/bips/blob/master/bip-0112.mediawiki)
func opCheckSequenceVerify(_ stack: inout [Data], context: ScriptContext) throws {
    let first = try getUnaryParam(&stack, keep: true)
    let sequence64 = try ScriptNumber(first, extendedLength: true, minimal: context.config.contains(.minimalData)).value

    guard
        first.count < 6,
        sequence64 >= 0,
        sequence64 <= InputSequence.maxCSVArgument
    else { throw ScriptError.invalidSequenceArgument }

    let sequence = InputSequence(sequence64)
    if sequence.isLocktimeDisabled { return }

    if context.transaction.version == .v1 { throw ScriptError.minimumTransactionVersionRequired }

    let txSequence = context.transaction.inputs[context.inputIndex].sequence
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
