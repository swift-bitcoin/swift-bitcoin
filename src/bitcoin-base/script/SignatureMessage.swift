import Foundation

/// Aka `sigMsg`. See https://en.bitcoin.it/wiki/OP_CHECKSIG
struct SignatureMessage: Equatable, Sendable {

    init(tx: Transaction, input inputIndex: Int, sighashType: SighashType, scriptCode: Data) {
        guard let script = try? Script(scriptCode) else {
            preconditionFailure()
        }
        var newIns = [Transaction.Input]()
        if sighashType.hasAnyCanPay {
            // Procedure for Hashtype SIGHASH_ANYONECANPAY
            // The txCopy input vector is resized to a length of one.
            // The current transaction input (with scriptPubKey modified to subScript) is set as the first and only member of this vector.
            newIns.append(.init(outpoint: tx.ins[inputIndex].outpoint, sequence: tx.ins[inputIndex].sequence, script: script))
        } else {
            tx.ins.enumerated().forEach { i, input in
                newIns.append(.init(
                    outpoint: input.outpoint,
                    // SIGHASH_NONE | SIGHASH_SINGLE - All other txCopy inputs aside from the current input are set to have an nSequence index of zero.
                    sequence: i == inputIndex || (!sighashType.isNone && !sighashType.isSingle) ? input.sequence : .initial,
                    // The scripts for all transaction inputs in txCopy are set to empty scripts (exactly 1 byte 0x00)
                    // The script for the current transaction input in txCopy is set to subScript (lead in by its length as a var-integer encoded!)
                    script: i == inputIndex ? script : .empty
                ))
            }
        }
        var newOuts: [TransactionOutput]
        // Procedure for Hashtype SIGHASH_SINGLE

        if sighashType.isSingle {
            // The output of txCopy is resized to the size of the current input index+1.
            // All other txCopy outputs aside from the output that is the same as the current input index are set to a blank script and a value of (long) -1.
            newOuts = []

            tx.outs.enumerated().forEach { i, out in
                guard i <= inputIndex else {
                    return
                }
                if i == inputIndex {
                    newOuts.append(out)
                } else if i < inputIndex {
                    // Value is "long -1" which means UInt64(bitPattern: -1) aka UInt64.max
                    newOuts.append(.init(value: -1, script: Script.empty))
                }
            }
        } else if sighashType.isNone {
            newOuts = []
        } else {
            newOuts = tx.outs
        }
        let txCopy = Transaction(
            version: tx.version,
            locktime: tx.locktime,
            ins: newIns,
            outs: newOuts
        )
        data = txCopy.data + sighashType.data(binaryFormat: .fullLength)
    }

    let data: Data
}
