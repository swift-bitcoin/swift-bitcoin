import Foundation

/// The output of a ``BitcoinTransaction``. While unspent also referred to as a _coin_.
public struct TransactionOutput: Equatable {
    
    /// Creates an output out of an amount (value) and a locking script.
    /// - Parameters:
    ///   - value: A Satoshi amount represented by this output.
    ///   - script: The script encumbering the specified value.
    public init(value: BitcoinAmount, script: BitcoinScript) {
        self.value = value
        self.script = script
    }

    /// The amount in _satoshis_ encumbered by this output.
    public let value: BitcoinAmount

    /// The script that locks this output.
    public let script: BitcoinScript
}
