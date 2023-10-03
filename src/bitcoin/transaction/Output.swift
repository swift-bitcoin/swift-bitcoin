import Foundation

/// The output of a ``Transaction``.
public struct Output: Equatable {

    public init(value: Amount, script: Data) {
        self.value = value
        self.script = script
    }

    /// The amount in satoshis encumbered by this output.
    public var value: Amount

    /// The script that locks this output.
    public var script: Data

    var data: Data {
        var ret = Data()
        ret += valueData
        ret += script // TODO: Eventually replace with `script.prefixedData`
        return ret
    }

    var size: Int {
        MemoryLayout.size(ofValue: value) + UInt64(script.count).varIntSize + script.count // TODO: Eventually replace with `script.prefixedSize`
    }

    private var valueData: Data {
        withUnsafeBytes(of: value) { Data($0) }
    }
}
