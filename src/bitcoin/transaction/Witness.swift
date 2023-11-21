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
