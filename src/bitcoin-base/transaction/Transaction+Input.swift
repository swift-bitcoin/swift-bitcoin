import Foundation
import BinaryParsing
import BitcoinCrypto

extension Transaction {
    /// A single input belonging to a ``Transaction``.
    public struct Input: Equatable, Sendable {

        // MARK: - Initializers

        /// Constructs a transaction input.
        /// - Parameters:
        ///   - outpoint: The output that this input is spending.
        ///   - sequence: This input's sequence number.
        ///   - script: Optional script to unlock the referenced output.
        ///   - witness: Optional witness data for this input. See BIP141 for more information.
        public init(outpoint: Outpoint, sequence: Sequence = .final, script: Script = .empty, /* BIP141 */ witness: Witness = []) {
            self.outpoint = outpoint
            self.sequence = sequence
            self.script = script

            // BIP141
            self.witness = witness
        }

        // MARK: - Instance Properties

        /// A reference to a previously unspent output of a prior transaction.
        public var outpoint: Outpoint

        /// The sequence number for this input.
        public var sequence: Sequence

        /// The script that unlocks the output associated with this input.
        public var script: Script

        /// BIP141 - Segregated witness data associated with this input.
        public var witness: Witness
    }
}

/// Data extensions.
extension Transaction.Input: BinaryCodable {
    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        outpoint = try decoder.decode()
        script = try Script(from: &decoder, format: .prefixed)
        sequence = try decoder.decode()
        witness = []
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(outpoint)
        script.countBytes(into: &counter, format: .prefixed)
        counter.count(sequence)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try outpoint.encode(into: &out)
        try script.encode(into: &out, format: .prefixed)
        try sequence.encode(into: &out)
    }

    /*
    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(outpoint)
        script.encode(into: &encoder, format: .prefixed)
        encoder.encode(sequence)
    }
    */
}
