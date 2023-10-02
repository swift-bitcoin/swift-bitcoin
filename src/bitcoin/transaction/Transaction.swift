/// Transactions summary
import Foundation

/// A bitcoin transaction.
public struct Transaction: Equatable {

    public init(version: Version, locktime: Locktime, inputs: [Input], outputs: [Output]) {
        self.version = version
        self.locktime = locktime
        self.inputs = inputs
        self.outputs = outputs
    }

    /// The transaction's version.
    public let version: Version

    /// Lock time value applied to this transaction. It represents the earliest time at which this transaction should be considered valid.
    public var locktime: Locktime

    /// All of the inputs consumed by this transaction.
    public var inputs: [Input]

    /// The outputs created by this transaction.
    public var outputs: [Output]
}
