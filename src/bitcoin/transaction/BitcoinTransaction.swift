import Foundation

/// A bitcoin transaction.
public struct BitcoinTransaction: Equatable {

    // MARK: - Initializers

    public init(version: TransactionVersion, locktime: TransactionLocktime = .disabled, inputs: [TransationInput], outputs: [TransactionOutput]) {
        self.version = version
        self.locktime = locktime
        self.inputs = inputs
        self.outputs = outputs
    }

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

        var inputs = [TransationInput]()
        for _ in 0 ..< inputsCount {
            guard let input = TransationInput(data) else {
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

    // MARK: - Instance Properties

    /// The transaction's version.
    public let version: TransactionVersion

    /// Lock time value applied to this transaction. It represents the earliest time at which this transaction should be considered valid.
    public let locktime: TransactionLocktime

    /// All of the inputs consumed by this transaction.
    public let inputs: [TransationInput]

    /// The outputs created by this transaction.
    public let outputs: [TransactionOutput]

    // MARK: - Computed Properties

    /// Raw format byte serialization of this transaction. Supports updated serialization format specified in BIP144.
    /// BIP144
    public var data: Data {
        var ret = Data()
        ret += version.data

        // BIP144
        if hasWitness {
            ret += Data([BitcoinTransaction.segwitMarker, BitcoinTransaction.segwitFlag])
        }
        ret += Data(varInt: inputsUInt64)
        ret += inputs.reduce(Data()) { $0 + $1.data }
        ret += Data(varInt: outputsUInt64)
        ret += outputs.reduce(Data()) { $0 + $1.data }

        // BIP144
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

    /// The transaction's identifier. More [here](https://learnmeabitcoin.com/technical/txid). Serialized as big-endian.
    public var identifier: Data { Data(hash256(identifierData).reversed()) }

    /// BIP141
    /// The transaction's witness identifier as defined in BIP141. More [here](https://river.com/learn/terms/w/wtxid/). Serialized as big-endian.
    public var witnessIdentifier: Data { Data(hash256(data).reversed()) }

    /// BIP141: Transaction weight is defined as Base transaction size * 3 + Total transaction size (ie. the same method as calculating Block weight from Base size and Total size).
    public var weight: Int { baseSize * 4 + witnessSize }

    /// BIP141: Total transaction size is the transaction size in bytes serialized as described in BIP144, including base data and witness data.
    public var size: Int { baseSize + witnessSize }

    ///  BIP141: Virtual transaction size is defined as Transaction weight / 4 (rounded up to the next integer).
    public var virtualSize: Int { Int((Double(weight) / 4).rounded(.up)) }

    public var isCoinbase: Bool {
        inputs.count == 1 && inputs[0].outpoint == TransactionOutpoint.coinbase
    }

    private var inputsUInt64: UInt64 { .init(inputs.count) }
    private var outputsUInt64: UInt64 { .init(outputs.count) }

    private var identifierData: Data {
        var ret = Data()
        ret += version.data
        ret += Data(varInt: inputsUInt64)
        ret += inputs.reduce(Data()) { $0 + $1.data }
        ret += Data(varInt: outputsUInt64)
        ret += outputs.reduce(Data()) { $0 + $1.data }
        ret += locktime.data
        return ret
    }

    /// BIP141: Base transaction size is the size of the transaction serialised with the witness data stripped.
    private var baseSize: Int {
        TransactionVersion.size + inputsUInt64.varIntSize + inputs.reduce(0) { $0 + $1.size } + outputsUInt64.varIntSize + outputs.reduce(0) { $0 + $1.size } + TransactionLocktime.size
    }

    /// BIP141 / BIP144
    private var witnessSize: Int {
        hasWitness ? (MemoryLayout.size(ofValue: BitcoinTransaction.segwitMarker) + MemoryLayout.size(ofValue: BitcoinTransaction.segwitFlag)) + inputs.reduce(0) { $0 + ($1.witness?.size ?? 0) } : 0
    }

    /// BIP141
    private var hasWitness: Bool { inputs.contains { $0.witness != .none } }

    // MARK: - Instance Methods

    /// Creates an outpoint from a particular output in this transaction to be used when creating an ``Input`` instance.
    public func outpoint(for output: Int) -> TransactionOutpoint? {
        guard output < outputs.count else {
            return .none
        }
        return .init(transaction: identifier, output: output)
    }

    // MARK: - Type Properties

    /// The total amount of bitcoin supply is actually less than this number. But `maxMoney` as a limit for any amount is a  consensus-critical constant.
    static let maxMoney = 2_100_000_000_000_000

    /// Coinbase transaction outputs can only be spent after this number of new blocks (network rule).
    static let coinbaseMaturity = 100

    static let maxBlockWeight = 4_000_000
    static let identifierSize = 32

    /// BIP141
    private static let segwitMarker = UInt8(0x00)

    /// BIP141
    private static let segwitFlag = UInt8(0x01)

    // MARK: - Type Methods

    // No type methods yet.
}
