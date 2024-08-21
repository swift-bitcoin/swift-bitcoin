import Foundation

private let bech32mConstant = UInt32(0x2bc830a3)
private let bech32Constant = UInt32(1)

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

public struct Bech32Encoder {

    public init(bech32m: Bool) {
        self.bech32m = bech32m
    }

    public let bech32m: Bool

    public func encode(_ hrp: String, values: Data) -> String {
        let checksum = createChecksum(hrp: hrp, values: values)
        var combined = values
        combined.append(checksum)
        guard let hrpBytes = hrp.data(using: .utf8) else { return "" }
        var ret = hrpBytes
        ret.append("1".data(using: .utf8)!)
        for i in combined {
            ret.append(encCharset[Int(i)])
        }
        return String(data: ret, encoding: .utf8) ?? ""
    }

    private func createChecksum(hrp: String, values: Data) -> Data {
        // If nothing specified we assume bech32 (not bech32m).
        let checksumConst = bech32m ? bech32mConstant : bech32Constant
        var enc = expandHRP(hrp)
        enc.append(values)
        enc.append(Data(repeating: 0x00, count: 6))
        let mod: UInt32 = polymod(enc) ^ checksumConst
        var ret: Data = Data(repeating: 0x00, count: 6)
        for i in 0..<6 {
            ret[i] = UInt8((mod >> (5 * (5 - i))) & 31)
        }
        return ret
    }
}

public struct Bech32Decoder {

    public init(bech32m: Bool? = .none) {
        self.bech32m = bech32m
    }

    public let bech32m: Bool?

    /// Decode Bech32 string
    public func decode(_ str: String) throws -> (hrp: String, checksum: Data, bech32m: Bool) {
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
        let (checksumOk, checksumBech32m) = verifyChecksum(hrp: hrp, checksum: values)
        guard checksumOk else {
            throw Error.checksumMismatch
        }
        return (hrp, Data(values[..<(vSize - 6)]), checksumBech32m)
    }

    private func verifyChecksum(hrp: String, checksum: Data) -> (result: Bool, bech32m: Bool) {
        var data = expandHRP(hrp)
        data.append(checksum)
        let result = polymod(data)
        guard result == bech32Constant || result == bech32mConstant else {
            return (false, false)
        }
        if let bech32m {
            return (
                bech32m && result == bech32mConstant || (!bech32m && result == bech32Constant),
                result == bech32mConstant
            )
        }
        return (true, result == bech32mConstant)
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

