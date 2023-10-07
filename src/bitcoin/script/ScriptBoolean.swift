import Foundation

/// A boolean value in the context of SCRIPT execution.
struct ScriptBoolean: Equatable {

    static let `false` = Self(false)
    static let `true` = Self(true)

    let value: Bool

    init(_ value: Bool) {
        self.value = value
    }

    init(_ data: Data) {
        let firstNonZeroIndex = data.firstIndex { $0 != 0 }
        if firstNonZeroIndex == data.endIndex - 1, let last = data.last, last == 0x80 {
            // Negative zero
            value = false
        } else {
            value = firstNonZeroIndex != .none
        }
    }

    var data: Data {
        value ? Data([1]) : Data()
    }

    var size: Int {
        value ? 1 : 0
    }

    func and(_ b: ScriptBoolean) -> ScriptBoolean {
        Self(value && b.value)
    }
}
