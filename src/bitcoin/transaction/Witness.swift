import Foundation

/// BIP141
/// Witness data associated with a particular ``Input``.
public struct Witness: Equatable {

    public init(_ elements: [Data]) {
        self.elements = elements
    }

    init?(_ data: Data) {
        var data = data
        guard let elementsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(elementsCount.varIntSize)
        elements = [Data]()
        for _ in 0 ..< elementsCount {
            guard let element = Data(varLenData: data) else {
                return nil
            }
            elements.append(element)
            data = data.dropFirst(element.varLenSize)
        }
    }

    /// The list of elements that makes up this witness.
    public var elements: [Data]

    /// Used by ``Transaction/data`` to support the serialization format specified in BIP144.
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
