import Foundation

/// A numerical value in the context of a script execution.
struct ScriptNumber: Equatable {

    static let zero = Self(unsafeValue: 0)
    static let one = Self(unsafeValue: 1)
    static let negativeOne = Self(unsafeValue: -1)

    private static let maxValue: Int = 0x0000007fffffffff
    private static let minValue: Int = -0x0000007fffffffff

    private(set) var value: Int

    init(_ value: Int) throws {
        guard value.magnitude <= Self.maxValue else {
            throw ScriptError.numberOverflow
        }
        self.value = value
    }

    init(_ value: UInt8) {
        self.init(unsafeValue: Int(value))
    }
    private init(unsafeValue value: Int) {
        self.value = value
    }

    init(_ data: Data, extendedLength: Bool = false) throws {
        // TODO: optionally check for minimal data (no leading zero bytes unless next previous byte is max)
        if data.isEmpty {
            value = 0
            return
        }
        let countLimit = extendedLength ? 5 : 4
        if data.count > countLimit {
            throw ScriptError.numberOverflow
        }
        let negative = if let last = data.last { last & 0b10000000 != 0 } else { false }
        var data = data
        data[data.endIndex - 1] &= 0b01111111 // We make it positive
        let padded = data + Data(repeating: 0, count: MemoryLayout<Int>.size - data.count)
        let magnitude = padded.withUnsafeBytes { $0.load(as: Int.self) }
        value = (negative ? -1 : 1) * magnitude
    }

    var data: Data {
        if value == 0 {
            return Data()
        }
        let magnitude = value.magnitude
        if magnitude < Int(pow(Double(2), 8 * 1 - 1)) {
            let signMask = UInt8(isNegative ? 0b10000000 : 0)
            let withSign = UInt8(magnitude) | signMask
            return withUnsafeBytes(of: withSign) { Data($0) }
        }
        if magnitude < Int(pow(Double(2), 8 * 2 - 1)) {
            let signMask = UInt16(isNegative ? 0x8000 : 0)
            let withSign = UInt16(magnitude) | signMask
            return withUnsafeBytes(of: withSign) { Data($0) }
        }
        if magnitude < Int(pow(Double(2), 8 * 3 - 1)) {
            let signMask = UInt32(isNegative ? 0x00800000 : 0)
            let withSign = UInt32(magnitude) | signMask
            var data = withUnsafeBytes(of: withSign) { Data($0) }
            data = data.dropLast(MemoryLayout<UInt32>.size - 3)
            return data
        }
        if magnitude < Int(pow(Double(2), 8 * 4 - 1)) {
            let signMask = UInt32(isNegative ? 0x80000000 : 0)
            let withSign = UInt32(magnitude) | signMask
            return withUnsafeBytes(of: withSign) { Data($0) }
        }
        if magnitude <= Self.maxValue {
            let signMask = UInt(isNegative ? 0x0000008000000000 : 0)
            let withSign = UInt(magnitude) | signMask
            var data = withUnsafeBytes(of: withSign) { Data($0) }
            data = data.dropLast(MemoryLayout<UInt>.size - 5)
            return data
        }
        preconditionFailure()
    }

    private var isNegative: Bool {
        value.signum() == -1
    }

    mutating func add(_ b: ScriptNumber) throws {
        let newValue = value + b.value
        if newValue.magnitude > Self.maxValue {
            throw ScriptError.numberOverflow
        }
        value = newValue
    }

    mutating func negate() {
        value = -value
    }
}
