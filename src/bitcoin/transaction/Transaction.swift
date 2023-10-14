/// Transactions summary
import Foundation

/// A bitcoin transaction.
public struct Transaction: Equatable {

    public init(version: Version, locktime: Locktime, inputs: [Input], outputs: [Output]) {
        self.version = version
        self.locktime = locktime
        self.inputs = inputs
        self.outputs = outputs
    }

    public init?(_ data: Data) {
        var data = data
        guard let version = Version(data) else {
            return nil
        }
        data = data.dropFirst(Version.size)

        // Check for marker and segwit flag
        let maybeSegwitMarker = data[data.startIndex]
        let maybeSegwitFlag = data[data.startIndex + 1]
        let isSegwit: Bool
        if maybeSegwitMarker == Transaction.segwitMarker && maybeSegwitFlag == Transaction.segwitFlag {
            isSegwit = true
            data = data.dropFirst(2)
        } else {
            isSegwit = false
        }

        guard let inputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(inputsCount.varIntSize)

        var inputs = [Input]()
        for _ in 0 ..< inputsCount {
            guard let input = Input(data) else {
                return nil
            }
            inputs.append(input)
            data = data.dropFirst(input.size)
        }

        guard let outputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(outputsCount.varIntSize)

        var outputs = [Output]()
        for _ in 0 ..< outputsCount {
            guard let out = Output(data) else {
                return nil
            }
            outputs.append(out)
            data = data.dropFirst(out.size)
        }

        if isSegwit {
            for i in inputs.indices {
                guard let witness = Witness(data) else {
                    return nil
                }
                inputs[i].witness = witness
                data = data.dropFirst(witness.size)
            }
        }

        guard let locktime = Locktime(data) else {
            return nil
        }
        data = data.dropFirst(Locktime.size)
        self.init(version: version, locktime: locktime, inputs: inputs, outputs: outputs)
    }

    /// The transaction's version.
    public let version: Version

    /// Lock time value applied to this transaction. It represents the earliest time at which this transaction should be considered valid.
    public var locktime: Locktime

    /// All of the inputs consumed by this transaction.
    public var inputs: [Input]

    /// The outputs created by this transaction.
    public var outputs: [Output]

    /// Raw format byte serialization of this transaction. Supports updated serialization format specified in BIP144.
    public var data: Data {
        var ret = Data()
        ret += version.data
        if hasWitness {
            ret += Data([Transaction.segwitMarker, Transaction.segwitFlag])
        }
        ret += Data(varInt: inputsUInt64)
        ret += inputs.reduce(Data()) { $0 + $1.data }
        ret += Data(varInt: outputsUInt64)
        ret += outputs.reduce(Data()) { $0 + $1.data }
        if hasWitness {
            ret += inputs.reduce(Data()) {
                guard let witness = $1.witness else {
                    return $0
                }
                return $0 + witness.data
            }
        }
        ret += locktime.data
        return ret
    }

    var idData: Data {
        var ret = Data()
        ret += version.data
        ret += Data(varInt: inputsUInt64)
        ret += inputs.reduce(Data()) { $0 + $1.data }
        ret += Data(varInt: outputsUInt64)
        ret += outputs.reduce(Data()) { $0 + $1.data }
        ret += locktime.data
        return ret
    }

    /// The transaction's identifier. More [here](https://learnmeabitcoin.com/technical/txid). Serialized as big-endian.
    public var id: Data { Data(hash256(idData).reversed()) }

    /// The transaction's witness identifier as defined in BIP-141. More [here](https://river.com/learn/terms/w/wtxid/). Serialized as big-endian.
    public var witnessID: Data { Data(hash256(data).reversed()) }

    public var size: Int { nonWitnessSize + witnessSize }

    private var inputsUInt64: UInt64 { .init(inputs.count) }
    private var outputsUInt64: UInt64 { .init(outputs.count) }

    private var nonWitnessSize: Int {
        Version.size + inputsUInt64.varIntSize + inputs.reduce(0) { $0 + $1.size } + outputsUInt64.varIntSize + outputs.reduce(0) { $0 + $1.size } + Locktime.size
    }

    /// Part of BIP-144 implementation.
    private var witnessSize: Int {
        hasWitness ? (MemoryLayout.size(ofValue: Transaction.segwitMarker) + MemoryLayout.size(ofValue: Transaction.segwitFlag)) + inputs.reduce(0) { $0 + ($1.witness?.size ?? 0) } : 0
    }

    private var hasWitness: Bool { inputs.contains { $0.witness != .none } }

    /// Initial simplified version of transaction verification that allows for script execution.
    public func verify(previousOutputs: [Output]) -> Bool{
        precondition(previousOutputs.count == inputs.count)
        for index in inputs.indices {
            var stack = [Data]()
            do {
                try inputs[index].script.run(&stack, transaction: self, inputIndex: index, previousOutputs: previousOutputs)
                try previousOutputs[index].script.run(&stack, transaction: self, inputIndex: index, previousOutputs: previousOutputs)
            } catch {
                return false
            }
        }
        return true
    }
    /// Creates an outpoint from a particular output in this transaction to be used when creating an ``Input`` instance.
    public func outpoint(for output: Int) -> Outpoint? {
        guard output < outputs.count else {
            return .none
        }
        return .init(transaction: id, output: output)
    }

    static let idSize = 32

    /// BIP-144
    private static let segwitMarker = UInt8(0x00)

    /// BIP-144
    private static let segwitFlag = UInt8(0x01)

    func checkSignature(extendedSignature: Data, publicKey: Data, inputIndex: Int, previousOutput: Output, scriptCode: Data) -> Bool {
        precondition(extendedSignature.count > 69, "Signature too short or missing hash type suffix.")
        precondition(extendedSignature.count <= 73, "Signature too long.")
        var sigTmp = extendedSignature
        guard let rawValue = sigTmp.popLast(), let sighashType = SighashType(rawValue: rawValue) else {
            preconditionFailure()
        }
        let sig = sigTmp
        let sighash = signatureHash(sighashType: sighashType, inputIndex: inputIndex, previousOutput: previousOutput, scriptCode: scriptCode)
        let result = verifyECDSA(sig: sig, msg: sighash, publicKey: publicKey)
        return result
    }


    /// Signature hash for legacy inputs.
    /// - Parameters:
    ///   - sighashType: Signature hash type.
    ///   - inputIndex: Transaction input index.
    ///   - previousOutput: Previous unspent transaction output corresponding to the transaction input being signed/verified.
    ///   - scriptCode: The executed script. For Pay-to-Script-Hash outputs it should correspond to the redeem script.
    /// - Returns: A hash value for use while either signing or verifying a transaction input.
    func signatureHash(sighashType: SighashType, inputIndex: Int, previousOutput: Output, scriptCode: Data) -> Data {
        if sighashType.isSingle && inputIndex >= outputs.count {
            // Note: The transaction that uses SIGHASH_SINGLE type of signature should not have more inputs than outputs. However if it does (because of the pre-existing implementation), it shall not be rejected, but instead for every "illegal" input (meaning: an input that has an index bigger than the maximum output index) the node should still verify it, though assuming the hash of 0000000000000000000000000000000000000000000000000000000000000001
            //
            // From [https://en.bitcoin.it/wiki/BIP_0143]:
            // In the original algorithm, a uint256 of 0x0000......0001 is committed if the input index for a SINGLE signature is greater than or equal to the number of outputs.
            return Data([0x01]) + Data(repeating: 0, count: 31)
        }
        let sigMsg = signatureMessage(sighashType: sighashType, inputIndex: inputIndex, scriptCode: scriptCode)
        return hash256(sigMsg)
    }

    /// Aka sigMsg. See https://en.bitcoin.it/wiki/OP_CHECKSIG
    func signatureMessage(sighashType: SighashType, inputIndex: Int, scriptCode: Data) -> Data {
        var newIns = [Input]()
        if sighashType.isAnyCanPay {
            // Procedure for Hashtype SIGHASH_ANYONECANPAY
            // The txCopy input vector is resized to a length of one.
            // The current transaction input (with scriptPubKey modified to subScript) is set as the first and only member of this vector.
            newIns.append(.init(outpoint: inputs[inputIndex].outpoint, sequence: inputs[inputIndex].sequence, script: .init(scriptCode)))
        } else {
            inputs.enumerated().forEach { i, input in
                newIns.append(.init(
                    outpoint: input.outpoint,
                    // SIGHASH_NONE | SIGHASH_SINGLE - All other txCopy inputs aside from the current input are set to have an nSequence index of zero.
                    sequence: i == inputIndex || sighashType.isAll ? input.sequence : .initial,
                    // The scripts for all transaction inputs in txCopy are set to empty scripts (exactly 1 byte 0x00)
                    // The script for the current transaction input in txCopy is set to subScript (lead in by its length as a var-integer encoded!)
                    script: i == inputIndex ? .init(scriptCode) : .empty
                ))
            }
        }
        var newOuts: [Output]
        // Procedure for Hashtype SIGHASH_SINGLE

        if sighashType.isSingle {
            // The output of txCopy is resized to the size of the current input index+1.
            // All other txCopy outputs aside from the output that is the same as the current input index are set to a blank script and a value of (long) -1.
            newOuts = []

            outputs.enumerated().forEach { i, out in
                guard i <= inputIndex else {
                    return
                }
                if i == inputIndex {
                    newOuts.append(out)
                } else if i < inputIndex {
                    // Value is "long -1" which means UInt64(bitPattern: -1) aka UInt64.max
                    newOuts.append(.init(value: Amount.max, script: SerializedScript.empty))
                }
            }
        } else if sighashType.isNone {
            newOuts = []
        } else {
            newOuts = outputs
        }
        let txCopy = Transaction(
            version: version,
            locktime: locktime,
            inputs: newIns,
            outputs: newOuts
        )
        return txCopy.data + sighashType.data32
    }
}
