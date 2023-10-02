import Foundation

/// Witness data associated with a particular ``Input``.
public struct Witness: Equatable {

    /// The list of elements that makes up this witness.
    public var elements: [Data]
    
    public init(_ elements: [Data]) {
        self.elements = elements
    }
}
