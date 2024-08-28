import Foundation

extension InputWitness {

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

    /// Used by ``BitcoinTransaction/data`` to support the serialization format specified in BIP144.
    var data: Data {
        var ret = Data(count: size)
        let offset = ret.addData(Data(varInt: UInt64(elements.count)))
        ret.addData(elements.reduce(Data()) { $0 + $1.varLenData }, at: offset)
        return ret
    }

    var size: Int {
        UInt64(elements.count).varIntSize + elements.varLenSize
    }
}
