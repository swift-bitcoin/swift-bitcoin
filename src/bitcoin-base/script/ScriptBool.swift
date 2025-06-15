import Foundation
import BitcoinCrypto

/// A boolean value in the context of SCRIPT execution.
public struct ScriptBool: Equatable, Sendable {

    public static let `false` = Self(false)
    public static let `true` = Self(true)

    public let value: Bool

    public init(_ value: Bool) {
        self.value = value
    }

    public func and(_ b: ScriptBool) -> ScriptBool {
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
            value = firstNonZeroIndex != nil
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

    public func encode(to encoder: inout BinaryEncoder) {
        if value {
            encoder.encode(Data([1]))
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        if value {
            counter.countSize(1)
        }
    }
}
