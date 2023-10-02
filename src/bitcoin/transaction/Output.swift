import Foundation

/// The output of a ``Transaction``.
public struct Output: Equatable {

    public init(value: Amount, script: Data) {
        self.value = value
        self.script = script
    }

    /// The amount in satoshis encumbered by this output.
    public var value: Amount

    /// The script that locks this output.
    public var script: Data
}
