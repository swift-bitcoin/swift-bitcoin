import Foundation

/// The output of a ``BitcoinTransaction``. While unspent also referred to as a _coin_.
public struct TransactionOutput: Equatable, Sendable {
    
    /// Creates an output out of an amount (value) and a locking script.
    /// - Parameters:
    ///   - value: A Satoshi amount represented by this output.
    ///   - script: The script encumbering the specified value.
    public init(value: BitcoinAmount, script: BitcoinScript = .empty) {
        self.value = value
        self.script = script
    }

    /// The amount in _satoshis_ encumbered by this output.
    public let value: BitcoinAmount

    /// The script that locks this output.
    public let script: BitcoinScript
}

/// Data extensions.
extension TransactionOutput {

    package init?(_ data: Data) {
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

    package var data: Data {
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
