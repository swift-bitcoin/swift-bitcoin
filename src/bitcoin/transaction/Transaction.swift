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

    /// The transaction's version.
    public let version: Version

    /// Lock time value applied to this transaction. It represents the earliest time at which this transaction should be considered valid.
    public var locktime: Locktime

    /// All of the inputs consumed by this transaction.
    public var inputs: [Input]

    /// The outputs created by this transaction.
    public var outputs: [Output]

    /// Standard serialization of this transaction.
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

    var size: Int { nonWitnessSize + witnessSize }

    private var inputsUInt64: UInt64 { .init(inputs.count) }
    private var outputsUInt64: UInt64 { .init(outputs.count) }

    private var nonWitnessSize: Int {
        Version.size + inputsUInt64.varIntSize + inputs.reduce(0) { $0 + $1.size } + outputsUInt64.varIntSize + outputs.reduce(0) { $0 + $1.size } + Locktime.size
    }

    private var witnessSize: Int {
        hasWitness ? (MemoryLayout.size(ofValue: Transaction.segwitMarker) + MemoryLayout.size(ofValue: Transaction.segwitFlag)) + inputs.reduce(0) { $0 + ($1.witness?.size ?? 0) } : 0
    }

    private var hasWitness: Bool { inputs.contains { $0.witness != .none } }

    static let idSize = 32

    private static let segwitMarker = UInt8(0x00)
    private static let segwitFlag = UInt8(0x01)
}
