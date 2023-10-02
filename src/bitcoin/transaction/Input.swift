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
    public init(outpoint: Outpoint, sequence: Sequence, script: Data = .init(), witness: Witness? = .none) {
        self.outpoint = outpoint
        self.sequence = sequence
        self.script = script
        self.witness = witness
    }

    //- MARK: Instance Properties

    /// A reference to a previously unspent output of a prior transaction.
    public var outpoint: Outpoint

    /// The sequence number for this input.
    public var sequence: Sequence

    /// The script that unlocks the output associated with this input.
    public var script: Data

    /// The segregated witness data introduced by BIP-141.
    public var witness: Witness?
    
    //- MARK: Instance Methods
    //- MARK: Type Properties
    //- MARK: Type Methods
}
