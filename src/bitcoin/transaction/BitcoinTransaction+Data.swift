import Foundation

extension BitcoinTransaction {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    /// BIP 144
    public init?(_ data: Data) {
        var data = data
        guard let version = TransactionVersion(data) else {
            return nil
        }
        data = data.dropFirst(TransactionVersion.size)

        // BIP144 - Check for marker and segwit flag
        let maybeSegwitMarker = data[data.startIndex]
        let maybeSegwitFlag = data[data.startIndex + 1]
        let isSegwit: Bool
        if maybeSegwitMarker == BitcoinTransaction.segwitMarker && maybeSegwitFlag == BitcoinTransaction.segwitFlag {
            isSegwit = true
            data = data.dropFirst(2)
        } else {
            isSegwit = false
        }

        guard let inputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(inputsCount.varIntSize)

        var inputs = [TransactionInput]()
        for _ in 0 ..< inputsCount {
            guard let input = TransactionInput(data) else {
                return nil
            }
            inputs.append(input)
            data = data.dropFirst(input.size)
        }

        guard let outputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(outputsCount.varIntSize)

        var outputs = [TransactionOutput]()
        for _ in 0 ..< outputsCount {
            guard let out = TransactionOutput(data) else {
                return nil
            }
            outputs.append(out)
            data = data.dropFirst(out.size)
        }

        // BIP144
        if isSegwit {
            for i in inputs.indices {
                guard let witness = InputWitness(data) else { return nil }
                data = data.dropFirst(witness.size)
                let input = inputs[i]
                inputs[i] = .init(outpoint: input.outpoint, sequence: input.sequence, script: input.script, witness: witness)
            }
        }

        guard let locktime = TransactionLocktime(data) else {
            return nil
        }
        data = data.dropFirst(TransactionLocktime.size)
        self.init(version: version, locktime: locktime, inputs: inputs, outputs: outputs)
    }

    // MARK: - Computed Properties

    /// Raw format byte serialization of this transaction. Supports updated serialization format specified in BIP144.
    /// BIP144
    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(version.data)

        // BIP144
        if hasWitness {
            offset = ret.addData(Data([BitcoinTransaction.segwitMarker, BitcoinTransaction.segwitFlag]), at: offset)
        }
        offset = ret.addData(Data(varInt: inputsUInt64), at: offset)
        offset = ret.addData(inputs.reduce(Data()) { $0 + $1.data }, at: offset)
        offset = ret.addData(Data(varInt: outputsUInt64), at: offset)
        offset = ret.addData(outputs.reduce(Data()) { $0 + $1.data }, at: offset)

        // BIP144
        if hasWitness {
            offset = ret.addData(inputs.reduce(Data()) {
                guard let witness = $1.witness else {
                    return $0
                }
                return $0 + witness.data
            }, at: offset)
        }

        ret.addData(locktime.data, at: offset)
        return ret
    }

    /// BIP141: Total transaction size is the transaction size in bytes serialized as described in BIP144, including base data and witness data.
    public var size: Int { baseSize + witnessSize }

    private var inputsUInt64: UInt64 { .init(inputs.count) }
    private var outputsUInt64: UInt64 { .init(outputs.count) }

    var identifierData: Data {
        var ret = Data(count: baseSize)
        var offset = ret.addData(version.data)
        offset = ret.addData(Data(varInt: inputsUInt64), at: offset)
        offset = ret.addData(inputs.reduce(Data()) { $0 + $1.data }, at: offset)
        offset = ret.addData(Data(varInt: outputsUInt64), at: offset)
        offset = ret.addData(outputs.reduce(Data()) { $0 + $1.data }, at: offset)
        ret.addData(locktime.data, at: offset)
        return ret
    }

    /// BIP141: Base transaction size is the size of the transaction serialised with the witness data stripped.
    /// AKA `identifierSize`
    var baseSize: Int {
        TransactionVersion.size + inputsUInt64.varIntSize + inputs.reduce(0) { $0 + $1.size } + outputsUInt64.varIntSize + outputs.reduce(0) { $0 + $1.size } + TransactionLocktime.size
    }

    /// BIP141 / BIP144
    var witnessSize: Int {
        hasWitness ? (MemoryLayout.size(ofValue: BitcoinTransaction.segwitMarker) + MemoryLayout.size(ofValue: BitcoinTransaction.segwitFlag)) + inputs.reduce(0) { $0 + ($1.witness?.size ?? 0) } : 0
    }

    static let coinbaseWitnessIdentifier = Data(count: identifierSize)

    /// BIP141
    private static let segwitMarker = UInt8(0x00)

    /// BIP141
    private static let segwitFlag = UInt8(0x01)

    // MARK: - Type Methods

    // No type methods yet.
}
