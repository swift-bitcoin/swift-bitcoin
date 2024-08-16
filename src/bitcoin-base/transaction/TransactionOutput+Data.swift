import Foundation

extension TransactionOutput {

    init?(_ data: Data) {
        guard data.count > MemoryLayout<BitcoinAmount>.size else {
            return nil
        }
        var data = data
        let value = data.withUnsafeBytes { $0.loadUnaligned(as: BitcoinAmount.self) }
        data = data.dropFirst(MemoryLayout.size(ofValue: value))
        guard let script = BitcoinScript(prefixedData: data) else {
            return nil
        }
        self.init(value: value, script: script)
    }

    var valueData: Data {
        Data(value: value)
    }

    var data: Data {
        var ret = Data(count: size)
        let offset = ret.addData(valueData)
        ret.addData(script.prefixedData, at: offset)
        return ret
    }

    var size: Int {
        Self.valueSize + script.prefixedSize
    }

    static var valueSize: Int {
        MemoryLayout<BitcoinAmount>.size
    }
}
