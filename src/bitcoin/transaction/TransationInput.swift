import Foundation

/// A single input of a ``Transaction``.
public struct TransationInput: Equatable {

    // MARK: - Initializers

    /// Constructs a transaction input.
    /// - Parameters:
    ///   - outpoint: the output that this input is spending.
    ///   - sequence: this input's sequence number.
    ///   - script: optional script to unlock the output.
    ///   - witness: optional witness data for this input. BIP141
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
