import Foundation

/// Encodes data into hexadecimal strings.
public struct Base16Encoder {

    public init() { }

    public func encode<D: DataProtocol>(_ d: D) -> String {
        let hexLen = d.count * 2
        var hexChars = [UInt8](repeating: 0, count: hexLen)
        var offset = 0

        d.regions.forEach { (_) in
            for i in d {
                hexChars[Int(offset * 2)] = itoh((i >> 4) & 0xF)
                hexChars[Int(offset * 2 + 1)] = itoh(i & 0xF)
                offset += 1
            }
        }
        return String(bytes: hexChars, encoding: .utf8)!
    }
}

/// Decodes raw data from hexadecimal strings.
public struct Base16Decoder {

    public enum Error: Swift.Error {
        case invalidHexValue, invalidString
    }

    public init() { }

    public func decode(_ hexString: String) throws -> Data {
        guard hexString.count.isMultiple(of: 2) else {
            throw Error.invalidString
        }

        let stringBytes: [UInt8] = Array(hexString.lowercased().data(using: String.Encoding.utf8)!)

        var data = Data()
        for i in stride(from: stringBytes.startIndex, to: stringBytes.endIndex - 1, by: 2) {
            let char1 = stringBytes[i]
            let char2 = stringBytes[i + 1]

            try data.append(htoi(char1) << 4 + htoi(char2))
        }
        return data
    }
}

private let charA = UInt8(UnicodeScalar("a").value)
private let char0 = UInt8(UnicodeScalar("0").value)

private func itoh(_ value: UInt8) -> UInt8 {
    return (value > 9) ? (charA + value - 10) : (char0 + value)
}

private func htoi(_ value: UInt8) throws -> UInt8 {
    switch value {
    case char0...char0 + 9:
        return value - char0
    case charA...charA + 5:
        return value - charA + 10
    default:
        throw Base16Decoder.Error.invalidHexValue
    }
}

// MARK: - Data Extensions

package extension Data {

    /// Create instance from string containing hex digits.
    init?(hex: String) {
        guard let decoded = try? Base16Decoder().decode(hex) else {
            return nil
        }
        self = decoded
    }
}

package extension DataProtocol {

    /// Hexadecimal (Base-16) string representation of data.
    var hex: String { Base16Encoder().encode(self) }
}
