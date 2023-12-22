import BigInt
import Foundation

/// A static utility class which provides Base58 encoding and decoding functionality.
enum Base58 {
    /// Length of checksum appended to Base58Check encoded strings.
    private static let checksumLength = 4

    private static let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".data(using: .ascii)!
    private static let zero = BigUInt(0)
    private static let radix = BigUInt(alphabet.count)

    /// Encode the given bytes into a Base58Check encoded string.
    /// - Parameter bytes: The bytes to encode.
    /// - Returns: A base58check encoded string representing the given bytes, or nil if encoding failed.
    static func base58CheckEncode(_ bytes: Data) -> String {
        let checksum = calculateChecksum(bytes)
        let checksummedBytes = bytes + checksum
        return Base58.base58Encode(checksummedBytes)
    }

    /// Decode the given Base58Check encoded string to bytes.
    /// - Parameter input: A base58check encoded input string to decode.
    /// - Returns: Bytes representing the decoded input, or nil if decoding failed.
    static func base58CheckDecode(_ input: String) -> Data? {
        guard let decodedChecksummedBytes = base58Decode(input) else {
            return .none
        }

        let decodedChecksum = decodedChecksummedBytes.suffix(checksumLength)
        let decodedBytes = decodedChecksummedBytes.prefix(upTo: decodedChecksummedBytes.count - checksumLength)
        let calculatedChecksum = calculateChecksum(decodedBytes)

        guard decodedChecksum.elementsEqual(calculatedChecksum, by: { $0 == $1 }) else {
            return .none
        }
        return decodedBytes
    }

    /// Encode the given bytes to a Base58 encoded string.
    /// - Parameter bytes: The bytes to encode.
    /// - Returns: A base58 encoded string representing the given bytes, or nil if encoding failed.
    static func base58Encode(_ bytes: Data) -> String {
        var answer: [UInt8] = []
        var integerBytes = BigUInt(Data(bytes))

        while integerBytes > 0 {
            let (quotient, remainder) = integerBytes.quotientAndRemainder(dividingBy: radix)
            answer.insert(alphabet[Int(remainder)], at: 0)
            integerBytes = quotient
        }

        let prefix = Array(bytes.prefix { $0 == 0 }).map { _ in alphabet[0] }
        answer.insert(contentsOf: prefix, at: 0)

        // swiftlint:disable force_unwrapping
        // Force unwrap as the given alphabet will always decode to UTF8.
        return String(bytes: answer, encoding: String.Encoding.utf8)!
        // swiftlint:enable force_unwrapping
    }

    /// Decode the given base58 encoded string to bytes.
    /// - Parameter input: The base58 encoded input string to decode.
    /// - Returns: Bytes representing the decoded input, or nil if decoding failed.
    static func base58Decode(_ input: String) -> Data? {
        var answer = zero
        var i = BigUInt(1)
        let byteString = input.data(using: .ascii)!

        for char in byteString.reversed() {
            guard let alphabetIndex = alphabet.firstIndex(of: char) else {
                return nil
            }
            answer += (i * BigUInt(alphabetIndex))
            i *= radix
        }

        let bytes = answer.serialize()
        return Array(byteString.prefix { i in i == alphabet[0] }) + bytes
    }

    /// Calculate a checksum for a given input by hashing twice and then taking the first four bytes.
    /// - Parameter input: The input bytes.
    /// - Returns: A byte array representing the checksum of the input bytes.
    private static func calculateChecksum(_ input: Data) -> Data {
        hash256(input).prefix(checksumLength)
    }
}
