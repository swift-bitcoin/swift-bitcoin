import Foundation

/// A numerical value in the context of a script execution.
///
/// From BIP62 (https://github.com/bitcoin/bips/blob/master/bip-0062.mediawiki#numbers )…
///
/// The native data type of stack elements is byte arrays, but some operations interpret arguments as integers. The used encoding is little endian with an explicit sign bit (the highest bit of the last byte). The shortest encodings for numbers are (with the range boundaries encodings given in hex).
///
/// `0`: `OP_0` (`0x00`)
/// `1`…`16`: `OP_1`…`OP_16` (`0x51`…`0x60`)
/// `-1`: `OP_1NEGATE` (`0x79`)
/// `-127`…-`2` and `17`…`127`: normal 1-byte data push (`01 FF`…`01 82` and `01 11`…`01 7F`).
/// `-32767`…`-128` and `128`…`32767`: normal 2-byte data push; (`02 FF FF`…`02 80 80` and `02 80 00`…`02 FF 7F`)
/// `-8388607`…`-32768` and `32768`…`8388607`: normal 3-byte data push; (`03 FF FF FF`…`03 00 80 80` and `03 00 80 00`…`03 FF FF 7F`)
/// `-2147483647`…`-8388608` and `8388608`…`2147483647`: normal 4-byte data push; (`04 FF FF FF FF`…`04 00 00 80 80` and `04 00 00 80 00`…`04 FF FF FF 7F`)
///
/// Any other numbers cannot be encoded.
///
/// In particular, note that zero could be encoded as `01 80` (negative zero) if using the non-shortest form is allowed.
///
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

extension ScriptNumber {

    /// BIP62 rule 4: Zero-padded number pushes Any time a script opcode consumes a stack value that is interpreted as a number, it must be encoded in its shortest possible form. 'Negative zero' is not allowed.
    init(_ data: Data, extendedLength: Bool = false, minimal: Bool = false) throws {
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

        // Negative zero has a special error code.
        if minimal, magnitude == 0, negative {
            throw ScriptError.negativeZero
        }

        // This would also catch negative zeroes.
        if minimal {
            // Check that the number is encoded with the minimum possible
            // number of bytes.
            //
            // If the most-significant-byte - excluding the sign bit - is zero
            // then we're not minimal. Note how this test also rejects the
            // negative-zero encoding, 0x80.
            if data.last! & 0x7f == 0 {
                // One exception: if there's more than one byte and the most
                // significant bit of the second-most-significant-byte is set
                // it would conflict with the sign bit. An example of this case
                // is +-255, which encode to 0xff00 and 0xff80 respectively.
                // (big-endian).
                if data.count <= 1 || (data[data.endIndex.advanced(by: -2)] & 0x80 == 0) {
                    throw ScriptError.zeroPaddedNumber
                }
            }
        }
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

    var size: Int {
        if value == 0 {
            return 0
        }
        let magnitude = value.magnitude
        if magnitude < Int(pow(Double(2), 8 * 1 - 1)) {
            return 1
        }
        if magnitude < Int(pow(Double(2), 8 * 2 - 1)) {
            return 2
        }
        if magnitude < Int(pow(Double(2), 8 * 3 - 1)) {
            return 3
        }
        if magnitude < Int(pow(Double(2), 8 * 4 - 1)) {
            return 4
        }
        if magnitude <= Self.maxValue {
            return 5
        }
        preconditionFailure() // Should never reach here
    }
}
