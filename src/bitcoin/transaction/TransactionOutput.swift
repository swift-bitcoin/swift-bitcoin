import Foundation

/// The output of a ``Transaction``.
public struct TransactionOutput: Equatable {

    public init(value: BitcoinAmount, script: BitcoinScript) {
        self.value = value
        self.script = script
    }

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

    /// The amount in satoshis encumbered by this output.
    public let value: BitcoinAmount

    /// The script that locks this output.
    public let script: BitcoinScript

    var data: Data {
        var ret = Data()
        ret += valueData
        ret += script.prefixedData
        return ret
    }

    var size: Int {
        MemoryLayout.size(ofValue: value) + script.prefixedSize
    }

    var valueData: Data {
        withUnsafeBytes(of: value) { Data($0) }
    }
}
