import Foundation

/// Length of checksum appended to Base58Check encoded strings.
private let checksumLength = 4

private let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".data(using: .ascii)!
private let radix = BigUInt(alphabet.count)

/// Produces checksumed Base58 strings used for legacy Bitcoin addresses.
public struct Base58Encoder {

    public init(withChecksum: Bool = true) {
        self.withChecksum = withChecksum
    }

    public let withChecksum: Bool

    public func encode(_ data: Data) -> String {
        let data = if withChecksum {
            data + calculateChecksum(data)
        } else {
            data
        }
        return base58Encode(data)
    }
}

/// Decodes raw data from Base58 strings.
public struct Base58Decoder {

    public init(withChecksum: Bool = true) {
        self.withChecksum = withChecksum
    }

    public let withChecksum: Bool

    public func decode(_ string: String) -> Data? {
        guard let data = base58Decode(string) else {
            return .none
        }
        guard withChecksum else {
            return data
        }
        let checksum = data.suffix(checksumLength)
        let payload = data.prefix(upTo: data.count - checksumLength)
        let expectedChecksum = calculateChecksum(payload)
        guard checksum == expectedChecksum else {
            return .none
        }
        return payload
    }
}


private func base58Encode(_ bytes: Data) -> String {
    var answer: [UInt8] = []
    var integerBytes = BigUInt(Data(bytes))

    while integerBytes > 0 {
        let (quotient, remainder) = integerBytes.quotientAndRemainder(dividingBy: radix)
        answer.insert(alphabet[Int(remainder)], at: 0)
        integerBytes = quotient
    }

    let prefix = Array(bytes.prefix { $0 == 0 }).map { _ in alphabet[0] }
    answer.insert(contentsOf: prefix, at: 0)

    // Force unwrap as the given alphabet will always decode to UTF8.
    return String(bytes: answer, encoding: .utf8)!
}

private func base58Decode(_ string: String) -> Data? {
    var answer = BigUInt(0)
    var i = BigUInt(1)
    let byteString = string.data(using: .ascii)!

    for char in byteString.reversed() {
        guard let alphabetIndex = alphabet.firstIndex(of: char) else {
            return .none
        }
        answer += (i * BigUInt(alphabetIndex))
        i *= radix
    }

    let bytes = answer.data
    return Array(byteString.prefix { i in i == alphabet[0] }) + bytes
}

private func calculateChecksum(_ data: Data) -> Data {
    Data(Hash256.hash(data: data)).prefix(checksumLength)
}
