import Foundation

/// [BIP112](https://github.com/bitcoin/bips/blob/master/bip-0112.mediawiki)
func opCheckSequenceVerify(_ stack: inout [Data], context: ScriptContext) throws {
    let first = try getUnaryParam(&stack, keep: true)
    let sequence64 = try ScriptNumber(first, extendedLength: true).value

    guard
        first.count < 6,
        sequence64 >= 0,
        sequence64 <= Sequence.maxCSVArgument
    else { throw ScriptError.invalidScript }
    
    let sequence = Sequence(sequence64)
    if sequence.isLocktimeDisabled { return }
    
    if context.transaction.version == .v1 { throw ScriptError.invalidScript }

    let txSequence = context.transaction.inputs[context.inputIndex].sequence
    if txSequence.isLocktimeDisabled { throw ScriptError.invalidScript }

    if let locktimeBlocks = sequence.locktimeBlocks, let txLocktimeBlocks = txSequence.locktimeBlocks {
        if locktimeBlocks > txLocktimeBlocks {
            throw ScriptError.invalidScript
        }
    } else if let seconds = sequence.locktimeSeconds, let txSeconds = txSequence.locktimeSeconds {
        if seconds > txSeconds {
            throw ScriptError.invalidScript
        }
    } else {
        throw ScriptError.invalidScript
    }
}
