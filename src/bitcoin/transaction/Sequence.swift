import Foundation

/// The sequence value of an ``Input``.
public struct Sequence: Equatable {

    public init(_ sequenceValue: Int) {
        self.sequenceValue = sequenceValue
    }

    /// The numeric sequence value.
    public let sequenceValue: Int
}
