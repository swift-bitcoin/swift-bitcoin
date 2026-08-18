import Foundation
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
        public let outpoint: Outpoint

        /// The sequence number for this input.
        public let sequence: Sequence

        /// The script that unlocks the output associated with this input.
        public let script: Script

        /// BIP141 - Segregated witness data associated with this input.
        public let witness: Witness
    }
}

/// Data extensions.
extension Transaction.Input: BinaryCodable {
    public init(from decoder: inout BinaryDecoder) throws {
        outpoint = try decoder.decode()
        script = try Script(prefixedFrom: &decoder)
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
