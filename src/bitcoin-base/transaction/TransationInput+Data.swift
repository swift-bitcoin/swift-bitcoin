import Foundation

extension TransactionInput {

    init?(_ data: Data) {
        var data = data
        guard let outpoint = TransactionOutpoint(data) else { return nil }
        data = data.dropFirst(TransactionOutpoint.size)

        guard let script = BitcoinScript(prefixedData: data) else { return nil }
        data = data.dropFirst(script.prefixedSize)

        guard let sequence = InputSequence(data) else { return nil }

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
