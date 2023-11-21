import Foundation

/// The output of a ``Transaction``.
public struct Output: Equatable {

    public init(value: Amount, script: SerializedScript) {
        self.value = value
        self.script = script
    }

    public init(value: Amount, script: ParsedScript) {
        self.init(value: value, script: script.serialized)
    }

    init?(_ data: Data) {
        guard data.count > MemoryLayout<Amount>.size else {
            return nil
        }
        var data = data
        let value = data.withUnsafeBytes { $0.loadUnaligned(as: Amount.self) }
        data = data.dropFirst(MemoryLayout.size(ofValue: value))
        guard let script = SerializedScript(prefixedData: data) else {
            return nil
        }
        self.init(value: value, script: script)
    }

    /// The amount in satoshis encumbered by this output.
    public var value: Amount

    /// The script that locks this output.
    public var script: SerializedScript

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
