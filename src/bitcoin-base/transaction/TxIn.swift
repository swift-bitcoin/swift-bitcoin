import Foundation
import BitcoinCrypto

/// A single input belonging to a ``BitcoinTx``.
public struct TxIn: Equatable, Sendable {

    // MARK: - Initializers

    /// Constructs a transaction input.
    /// - Parameters:
    ///   - outpoint: The output that this input is spending.
    ///   - sequence: This input's sequence number.
    ///   - script: Optional script to unlock the referenced output.
    ///   - witness: Optional witness data for this input. See BIP141 for more information.
    public init(outpoint: TxOutpoint, sequence: TxInSequence = .final, script: BitcoinScript = .empty, /* BIP141 */ witness: TxWitness = []) {
        self.outpoint = outpoint
        self.sequence = sequence
        self.script = script

        // BIP141
        self.witness = witness
    }

    // MARK: - Instance Properties

    /// A reference to a previously unspent output of a prior transaction.
    public var outpoint: TxOutpoint

    /// The sequence number for this input.
    public var sequence: TxInSequence

    /// The script that unlocks the output associated with this input.
    public var script: BitcoinScript

    /// BIP141 - Segregated witness data associated with this input.
    public var witness: TxWitness
}

/// Data extensions.
extension TxIn: BinaryCodable {
    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        outpoint = try decoder.decode()
        script = try BitcoinScript(prefixedFrom: &decoder)
        sequence = try decoder.decode()
        witness = []
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(outpoint)
        script.encodePrefixed(to: &encoder)
        encoder.encode(sequence)
    }
    
    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(outpoint)
        script.encodingSizePrefixed(&counter)
        counter.count(sequence)
    }
}
