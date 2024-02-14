import Foundation

/// A single input belonging to a ``BitcoinTransaction``.
public struct TransactionInput: Equatable {

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
