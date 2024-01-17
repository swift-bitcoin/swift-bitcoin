import Foundation

/// BIP141
/// Witness data associated with a particular ``Input``.
public struct InputWitness: Equatable {

    public init(_ elements: [Data]) {
        self.elements = elements
    }

    /// The list of elements that makes up this witness.
    public var elements: [Data]

    /// BIP341
    var taprootAnnex: Data? {
        // If there are at least two witness elements, and the first byte of the last element is 0x50, this last element is called annex a
        if elements.count > 1, let maybeAnnex = elements.last, let firstElem = maybeAnnex.first, firstElem == 0x50 {
            return maybeAnnex
        } else {
            return .none
        }
    }
}
