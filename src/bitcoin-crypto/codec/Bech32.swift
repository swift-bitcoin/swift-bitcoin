import Foundation

private let gen: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]

/// Bech32 checksum delimiter
private let checksumMarker: String = "1"

/// Bech32 character set for encoding
private let encCharset: Data = "qpzry9x8gf2tvdw0s3jn54khce6mua7l".data(using: .utf8)!

/// Bech32 character set for decoding
private let decCharset: [Int8] = [
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
     15, -1, 10, 17, 21, 20, 26, 30,  7,  5, -1, -1, -1, -1, -1, -1,
     -1, 29, -1, 24, 13, 25,  9,  8, 23, -1, 18, 22, 31, 27, 19, -1,
     1,  0,  3, 16, 11, 28, 12, 14,  6,  4,  2, -1, -1, -1, -1, -1,
     -1, 29, -1, 24, 13, 25,  9,  8, 23, -1, 18, 22, 31, 27, 19, -1,
     1,  0,  3, 16, 11, 28, 12, 14,  6,  4,  2, -1, -1, -1, -1, -1
]

public enum Bech32Variant: Sendable, CustomStringConvertible {

    case bech32, m

    public var description: String {
        switch self {
        case .bech32: "bech32"
        case .m: "bech32m"
        }
    }

    var constant: UInt32 {
        switch self {
        case .bech32: 1
        case .m: 0x2bc830a3
        }
    }
}

public struct Bech32Encoder: Sendable {

    public init(_ variant: Bech32Variant) {
        self.variant = variant
    }

    public let variant: Bech32Variant

    public func encode(_ hrp: String, values: Data) -> String {
        let checksum = createChecksum(hrp: hrp, values: values)
        var combined = values
        combined.append(checksum)
        let hrpBytes = hrp.data(using: .utf8)!
        var ret = hrpBytes
        ret.append("1".data(using: .utf8)!)
        for i in combined {
            ret.append(encCharset[Int(i)])
        }
        return String(data: ret, encoding: .utf8)!
    }

    private func createChecksum(hrp: String, values: Data) -> Data {
        var enc = expandHRP(hrp)
        enc.append(values)
        enc.append(Data(repeating: 0x00, count: 6))
        let mod: UInt32 = polymod(enc) ^ variant.constant
        var ret: Data = Data(repeating: 0x00, count: 6)
        for i in 0..<6 {
            ret[i] = UInt8((mod >> (5 * (5 - i))) & 31)
        }
        return ret
    }
}

public struct Bech32Decoder: Sendable {

    public init(_ variant: Bech32Variant? = .none) {
        self.variant = variant
    }

    public let variant: Bech32Variant?

    /// Decode Bech32 string
    public func decode(_ str: String) throws -> (hrp: String, checksum: Data, detectedVariant: Bech32Variant) {
        guard let strBytes = str.data(using: .utf8) else {
            throw Error.nonUTF8String
        }
        guard strBytes.count <= 90 else {
            throw Error.stringLengthExceeded
        }
        var lower: Bool = false
        var upper: Bool = false
        for c in strBytes {
            // printable range
            if c < 33 || c > 126 {
                throw Error.nonPrintableCharacter
            }
            // 'a' to 'z'
            if c >= 97 && c <= 122 {
                lower = true
            }
            // 'A' to 'Z'
            if c >= 65 && c <= 90 {
                upper = true
            }
        }
        if lower && upper {
            throw Error.invalidCase
        }
        guard let pos = str.range(of: checksumMarker, options: .backwards)?.lowerBound else {
            throw Error.noChecksumMarker
        }
        let intPos: Int = str.distance(from: str.startIndex, to: pos)
        guard intPos >= 1 else {
            throw Error.incorrectHrpSize
        }
        guard intPos + 7 <= str.count else {
            throw Error.incorrectChecksumSize
        }
        let vSize: Int = str.count - 1 - intPos
        var values: Data = Data(repeating: 0x00, count: vSize)
        for i in 0..<vSize {
            let c = strBytes[i + intPos + 1]
            let decInt = decCharset[Int(c)]
            if decInt == -1 {
                throw Error.invalidCharacter
            }
            values[i] = UInt8(decInt)
        }
        let hrp = String(str[..<pos]).lowercased()
        let verificationResult = verifyChecksum(hrp: hrp, checksum: values)
        guard verificationResult.checksumValid, let detectedVariant = verificationResult.detectedVariant else {
            throw Error.checksumMismatch
        }
        return (hrp, Data(values[..<(vSize - 6)]), detectedVariant)
    }

    private func verifyChecksum(hrp: String, checksum: Data) -> (checksumValid: Bool, detectedVariant: Bech32Variant?) {
        var data = expandHRP(hrp)
        data.append(checksum)
        let result = polymod(data)
        guard result == Bech32Variant.bech32.constant || result == Bech32Variant.m.constant else {
            return (false, .none)
        }
        guard let variant else {
            // Decoder configuration does not specify a variant so we auto-detect.
            return (true, result == Bech32Variant.bech32.constant ? .bech32 : .m)
        }
        return (result == variant.constant, variant)
    }
}

extension Bech32Decoder {
    public enum Error: LocalizedError {
        case nonUTF8String,
             nonPrintableCharacter,
             invalidCase,
             noChecksumMarker,
             incorrectHrpSize,
             incorrectChecksumSize,
             stringLengthExceeded,
             invalidCharacter,
             checksumMismatch

        public var errorDescription: String {
            switch self {
            case .checksumMismatch:
                "Checksum doesn't match"
            case .incorrectChecksumSize:
                "Checksum size too low"
            case .incorrectHrpSize:
                "Human-readable-part is too small or empty"
            case .invalidCase:
                "String contains mixed case characters"
            case .invalidCharacter:
                "Invalid character met on decoding"
            case .noChecksumMarker:
                "Checksum delimiter not found"
            case .nonPrintableCharacter:
                "Non printable character in input string"
            case .nonUTF8String:
                "String cannot be decoded by utf8 decoder"
            case .stringLengthExceeded:
                "Input string is too long"
            }
        }
    }
}

/// Find the polynomial with value coefficients mod the generator as 30-bit.
private func polymod(_ values: Data) -> UInt32 {
    var chk: UInt32 = 1
    for v in values {
        let top = (chk >> 25)
        chk = (chk & 0x1ffffff) << 5 ^ UInt32(v)
        for i: UInt8 in 0..<5 {
            chk ^= ((top >> i) & 1) == 0 ? 0 : gen[Int(i)]
        }
    }
    return chk
}

/// Expand a HRP for use in checksum computation.
private func expandHRP(_ hrp: String) -> Data {
    guard let hrpBytes = hrp.data(using: .utf8) else { return Data() }
    var result = Data(repeating: 0x00, count: hrpBytes.count*2+1)
    for (i, c) in hrpBytes.enumerated() {
        result[i] = c >> 5
        result[i + hrpBytes.count + 1] = c & 0x1f
    }
    result[hrp.count] = 0
    return result
}

