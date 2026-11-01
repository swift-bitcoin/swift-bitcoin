import Foundation
@testable import BitcoinCrypto
import Testing

/// The vendored swift-bitcoin coder (Codec/Base16.swift). Written against its public behavior, so
/// the same tests check any replacement implementation.
@Suite("Base16")
struct Base16Tests {
    @Test(arguments: [
        ([UInt8](), ""), ([0x00], "00"), ([0x0A], "0a"), ([0xFF], "ff"),
        ([0x00, 0x0A, 0xFF], "000aff"), ([0xDE, 0xAD, 0xBE, 0xEF], "deadbeef"),
    ])
    func encodesLowercaseWithoutPrefix(bytes: [UInt8], expected: String) {
        #expect(Base16Encoder().encode(bytes) == expected)
        #expect(Data(bytes).hex == expected)
        #expect(bytes.hex == expected)
    }

    @Test(arguments: ["deadbeef", "DEADBEEF", "DeAdBeEf"])
    func decodesEitherCase(text: String) throws {
        #expect(try Base16Decoder().decode(text) == Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(Data(hex: text) == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test func emptyStringIsEmptyData() throws {
        #expect(try Base16Decoder().decode("").isEmpty)
    }

    @Test(arguments: ["0", "abc", "00000"])
    func oddLengthIsInvalidString(text: String) {
        #expect(throws: Base16Decoder.Error.invalidString) { try Base16Decoder().decode(text) }
        #expect(Data(hex: text) == nil)
    }

    /// No prefix, sign, whitespace or separator is part of the format.
    @Test(arguments: ["0g", "g0", "0x00", "+0", " 0", "0 ", "0:00", "0\n"])
    func nonHexCharacterIsInvalidHexValue(text: String) {
        #expect(throws: Base16Decoder.Error.invalidHexValue) { try Base16Decoder().decode(text) }
        #expect(Data(hex: text) == nil)
    }

    /// Non-ASCII input is rejected; which of the two errors is reported is unspecified.
    @Test(arguments: ["\u{FF10}0", "é0", "0é", "€€", "00\u{301}0"])
    func nonASCIIIsRejected(text: String) {
        #expect(throws: Base16Decoder.Error.self) { try Base16Decoder().decode(text) }
        #expect(Data(hex: text) == nil)
    }

    @Test func roundTripsEveryByteValueAndRandomData() throws {
        let everyByte = (0...255).map(UInt8.init)
        #expect(try Base16Decoder().decode(Base16Encoder().encode(everyByte)) == Data(everyByte))
        var rng = SplitMix64(seed: 100)
        for length in 0..<200 {
            let bytes = (0..<length).map { _ in UInt8.random(in: .min ... .max, using: &rng) }
            let text = Base16Encoder().encode(bytes)
            #expect(text.count == 2 * length)
            #expect(try Base16Decoder().decode(text) == Data(bytes))
            #expect(try Base16Decoder().decode(text.uppercased()) == Data(bytes))
        }
    }
}
