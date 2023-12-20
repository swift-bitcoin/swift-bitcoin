import Foundation

/// [BIP65](https://github.com/bitcoin/bips/blob/master/bip-0065.mediawiki)
func opCheckLockTimeVerify(_ stack: inout [Data], context: ScriptContext) throws {
    let first = try getUnaryParam(&stack, keep: true)
    let locktime64 = try ScriptNumber(first, extendedLength: true).value

    guard
        first.count < 6,
        locktime64 >= 0,
        locktime64 <= UInt32.max
    else { throw ScriptError.invalidLockTimeArgument }

    let locktime = TransactionLocktime(locktime64)

    if let blockHeight = locktime.blockHeight, let txBlockHeight = context.transaction.locktime.blockHeight {
        if blockHeight > txBlockHeight {
            throw ScriptError.lockTimeHeightEarly
        }
    } else if let seconds = locktime.secondsSince1970, let txSeconds = context.transaction.locktime.secondsSince1970 {
        if seconds > txSeconds {
            throw ScriptError.lockTimeSecondsEarly
        }
    } else {
        throw ScriptError.invalidLockTime
    }

    if context.transaction.inputs[context.inputIndex].sequence == .final { throw ScriptError.inputSequenceFinal }
}
