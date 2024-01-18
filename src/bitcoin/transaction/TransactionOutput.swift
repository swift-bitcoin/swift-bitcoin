import Foundation

/// The output of a ``Transaction``.
public struct TransactionOutput: Equatable {

    public init(value: BitcoinAmount, script: BitcoinScript) {
        self.value = value
        self.script = script
    }

    /// The amount in satoshis encumbered by this output.
    public let value: BitcoinAmount

    /// The script that locks this output.
    public let script: BitcoinScript
}
