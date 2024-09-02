import Foundation

/// A single input belonging to a ``BitcoinTransaction``.
public struct TransactionInput: Equatable, Sendable {

    // MARK: - Initializers

    /// Constructs a transaction input.
    /// - Parameters:
    ///   - outpoint: The output that this input is spending.
    ///   - sequence: This input's sequence number.
    ///   - script: Optional script to unlock the referenced output.
    ///   - witness: Optional witness data for this input. See BIP141 for more information.
    public init(outpoint: TransactionOutpoint, sequence: InputSequence, script: BitcoinScript = .empty, /* BIP141 */ witness: InputWitness? = .none) {
        self.outpoint = outpoint
        self.sequence = sequence
        self.script = script

        // BIP141
        self.witness = witness
    }

    // MARK: - Instance Properties

    /// A reference to a previously unspent output of a prior transaction.
    public let outpoint: TransactionOutpoint

    /// The sequence number for this input.
    public let sequence: InputSequence

    /// The script that unlocks the output associated with this input.
    public let script: BitcoinScript

    /// BIP141 - Segregated witness data associated with this input.
    public let witness: InputWitness?
}

/// Data extensions.
extension TransactionInput {

    init?(_ data: Data) {
        var data = data
        guard let outpoint = TransactionOutpoint(data) else { return nil }
        data = data.dropFirst(TransactionOutpoint.size)

        guard let script = BitcoinScript(prefixedData: data) else { return nil }
        data = data.dropFirst(script.prefixedSize)

        guard let sequence = InputSequence(data) else { return nil }

        self.init(outpoint: outpoint, sequence: sequence, script: script)
    }

    // MARK: - Instance Properties

    /// Used by ``BitcoinTransaction/data``.
    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(outpoint.data)
        offset = ret.addData(script.prefixedData, at: offset)
        ret.addData(sequence.data, at: offset)
        return ret
    }

    /// Used by ``BitcoinTransaction/size``.
    var size: Int {
        TransactionOutpoint.size + script.prefixedSize + InputSequence.size
    }
}
