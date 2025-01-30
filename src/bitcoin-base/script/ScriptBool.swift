import Foundation
import BitcoinCrypto

/// A boolean value in the context of SCRIPT execution.
struct ScriptBool: Equatable {

    static let `false` = Self(false)
    static let `true` = Self(true)

    let value: Bool

    init(_ value: Bool) {
        self.value = value
    }

    func and(_ b: ScriptBool) -> ScriptBool {
        Self(value && b.value)
    }
}

extension ScriptBool: BinaryEncodable {

    init(_ data: Data) {
        let firstNonZeroIndex = data.firstIndex { $0 != 0 }
        if firstNonZeroIndex == data.endIndex - 1, let last = data.last, last == 0x80 {
            // Negative zero
            value = false
        } else {
            value = firstNonZeroIndex != .none
        }
    }

    // Enforce `MINIMALIF` rule.
    init(minimalData: Data) throws {
        if minimalData == Data() {
            value = false
        } else if minimalData == Data([1]) {
            value = true
        } else {
            throw ScriptError.nonMinimalBoolean
        }
    }

    func encode(to encoder: inout BinaryEncoder) {
        if value {
            encoder.encode(Data([1]))
        }
    }

    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        if value {
            counter.countSize(1)
        }
    }
}
