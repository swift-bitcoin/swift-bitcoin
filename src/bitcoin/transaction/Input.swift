import Foundation

/// A single input of a ``Transaction``.
public struct Input: Equatable {

    //- MARK: Initializers

    /// Constructs a transaction input.
    /// - Parameters:
    ///   - outpoint: the output that this input is spending.
    ///   - sequence: this input's sequence number.
    ///   - script: optional script to unlock the output.
    ///   - witness: optional witness data for this input.
    public init(outpoint: Outpoint, sequence: Sequence, script: SerializedScript = .empty, witness: Witness? = .none) {
        self.outpoint = outpoint
        self.sequence = sequence
        self.script = script
        self.witness = witness
    }

    public init(outpoint: Outpoint, sequence: Sequence, script: ParsedScript, witness: Witness? = .none) {
        self.init(outpoint: outpoint, sequence: sequence, script: script.serialized, witness: witness)
    }

    init?(_ data: Data) {
        var offset = data.startIndex
        guard let outpoint = Outpoint(data) else {
            return nil
        }
        offset += Outpoint.size

        guard let script = SerializedScript(prefixedData: data[offset...]) else {
            return nil
        }
        offset += script.prefixedSize

        guard let sequence = Sequence(data[offset...]) else {
            return nil
        }
        offset += Sequence.size

        self.init(outpoint: outpoint, sequence: sequence, script: script)
    }

    //- MARK: Instance Properties

    /// A reference to a previously unspent output of a prior transaction.
    public var outpoint: Outpoint

    /// The sequence number for this input.
    public var sequence: Sequence

    /// The script that unlocks the output associated with this input.
    public var script: SerializedScript

    /// The segregated witness data introduced by BIP-141.
    public var witness: Witness?

    /// Used by ``Transaction/data``.
    var data: Data {
        var ret = Data()
        ret += outpoint.data
        ret += script.prefixedData
        ret += sequence.data
        return ret
    }

    /// Used by ``Transaction/size``.
    var size: Int {
        Outpoint.size + script.prefixedSize + Sequence.size
    }

    //- MARK: Instance Methods
    //- MARK: Type Properties
    //- MARK: Type Methods
}
