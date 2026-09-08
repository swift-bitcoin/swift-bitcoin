import Foundation
import BitcoinCrypto

extension SignatureMessage {

    /// BIP143: SegWit v0 signature message (sigMsg).
    struct Segwit: Equatable, Sendable {

        private init() { fatalError() }

        let data: Data
    }
}

extension SignatureMessage.Segwit {
    init(tx: Transaction, input inputIndex: Int, sighashType: SighashType, scriptCode: Data, prevout: TransactionOutput) {
        let amount = prevout.value
        //If the ANYONECANPAY flag is not set, hashPrevouts is the double SHA256 of the serialization of all input outpoints;
        // Otherwise, hashPrevouts is a uint256 of 0x0000......0000.
        var hashPrevouts: Data
        if sighashType.hasAnyCanPay {
            hashPrevouts = Data(repeating: 0, count: 32)
        } else {
            let prevouts = tx.ins.reduce(Data()) { $0 + $1.outpoint.data }
            hashPrevouts = Data(Hash256.hash(data: prevouts))
        }

        // If none of the ANYONECANPAY, SINGLE, NONE sighash type is set, hashSequence is the double SHA256 of the serialization of nSequence of all inputs;
        // Otherwise, hashSequence is a uint256 of 0x0000......0000.
        let hashSequence: Data
        if !sighashType.hasAnyCanPay && !sighashType.isSingle && !sighashType.isNone {
            let sequence = tx.ins.reduce(Data()) {
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
            let outsData = tx.outs.reduce(Data()) { $0 + $1.data }
            hashOuts = Data(Hash256.hash(data: outsData))
        } else if sighashType.isSingle && inputIndex < tx.outs.count {
            hashOuts = Data(Hash256.hash(data: tx.outs[inputIndex].data))
        } else {
            hashOuts = Data(repeating: 0, count: 32)
        }

        let outpointData = tx.ins[inputIndex].outpoint.data
        let scriptCodeData = VarInt(scriptCode.count).data + scriptCode
        let amountData = Data(capacity: MemoryLayout<Int64>.size) { out in
            out.append(Int64(amount), as: Int64.self, .littleEndian)
        }

        let sequenceData = tx.ins[inputIndex].sequence.data

        let remainingData = sequenceData + hashOuts + tx.locktime.data + sighashType.data(binaryFormat: .fullLength)
        data = tx.version.data + hashPrevouts + hashSequence + outpointData + scriptCodeData + amountData + remainingData
    }
}
