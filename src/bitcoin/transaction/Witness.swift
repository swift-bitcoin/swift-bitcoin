import Foundation

/// Witness data associated with a particular ``Input``.
public struct Witness: Equatable {

    public init(_ elements: [Data]) {
        self.elements = elements
    }

    /// The list of elements that makes up this witness.
    public var elements: [Data]

    var data: Data {
        var ret = Data()
        ret += Data(varInt: UInt64(elements.count))
        ret += elements.reduce(Data()) { $0 + $1.varLenData }
        return ret
    }

    var size: Int {
        UInt64(elements.count).varIntSize + elements.varLenSize
    }
}
