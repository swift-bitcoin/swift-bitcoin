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

    /// Creates an outpoint from a particular output in this transaction to be used when creating an ``Input`` instance.
    public func outpoint(for output: Int) -> Outpoint? {
        guard output < outputs.count else {
            return .none
        }
        return .init(transaction: Data(), output: output)
    }

    static let idSize = 32

    /// BIP-144
    private static let segwitMarker = UInt8(0x00)

    /// BIP-144
    private static let segwitFlag = UInt8(0x01)
}
