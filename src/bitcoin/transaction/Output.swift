import Foundation

/// The output of a ``Transaction``.
public struct Output: Equatable {

    public init(value: Amount, script: Script) {
        self.value = value
        self.script = script
    }

    init?(_ data: Data) {
        guard data.count > MemoryLayout<Amount>.size else {
            return nil
        }
        var data = data
        let value = data.withUnsafeBytes { $0.loadUnaligned(as: Amount.self) }
        data = data.dropFirst(MemoryLayout.size(ofValue: value))
        guard let script = Script(prefixedData: data) else {
            return nil
        }
        self.init(value: value, script: script)
    }

    /// The amount in satoshis encumbered by this output.
    public let value: Amount

    /// The script that locks this output.
    public let script: Script

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
