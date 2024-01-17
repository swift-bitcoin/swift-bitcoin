import Foundation

extension TransationInput {

    init?(_ data: Data) {
        var offset = data.startIndex
        guard let outpoint = TransactionOutpoint(data) else {
            return nil
        }
        offset += TransactionOutpoint.size

        guard let script = BitcoinScript(prefixedData: data[offset...]) else {
            return nil
        }
        offset += script.prefixedSize

        guard let sequence = InputSequence(data[offset...]) else {
            return nil
        }
        offset += InputSequence.size

        self.init(outpoint: outpoint, sequence: sequence, script: script)
    }

    // MARK: - Instance Properties

    /// Used by ``Transaction/data``.
    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(outpoint.data)
        offset = ret.addData(script.prefixedData, at: offset)
        ret.addData(sequence.data, at: offset)
        return ret
    }

    /// Used by ``Transaction/size``.
    var size: Int {
        TransactionOutpoint.size + script.prefixedSize + InputSequence.size
    }
}
