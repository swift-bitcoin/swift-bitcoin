import Testing
import Foundation
@testable import BitcoinWallet
import BitcoinCrypto
import BitcoinBase

/// https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki#test-vectors
struct BIP173Tests {

    typealias ValidAddressData = (address: String, script: [UInt8])
    typealias InvalidAddressData = (hrp: String, version: Int, programLen: Int)

    @Test("Valid checksum", arguments: [
        "A12UEL5L",
        "an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs",
        "abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw",
        "11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j",
        "split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w",
        "?1ezyfcl"
    ])
    func validChecksum(valid: String) throws {
        let decoded = try Bech32Decoder(.bech32).decode(valid)
        #expect(!decoded.hrp.isEmpty, "Empty result for \"\(valid)\"")
        let recoded = Bech32Encoder(.bech32).encode(decoded.hrp, values: decoded.checksum)
        #expect(valid.lowercased() == recoded.lowercased(), "Roundtrip encoding failed: \(valid) != \(recoded)")
    }

    @Test("Invalid checksum", arguments: [
        (" 1nwldj5", Bech32Decoder.Error.nonPrintableCharacter),
        ("\u{7f}1axkwrx", .nonPrintableCharacter),
        ("an84characterslonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1569pvx", .stringLengthExceeded),
        ("pzry9x0s0muk", .noChecksumMarker),
        ("1pzry9x0s0muk", .incorrectHrpSize),
        ("x1b4n0q5v", .invalidCharacter),
        ("li1dgmt3", .incorrectChecksumSize),
        ("de1lg7wt\u{ff}", .nonPrintableCharacter),
        ("10a06t8", .incorrectHrpSize),
        ("1qzzfhee", .incorrectHrpSize)
    ])
    func invalidChecksum(encoded: String, reason: Bech32Decoder.Error) {
        #expect(throws: reason) {
            try Bech32Decoder(.bech32).decode(encoded)
        }
    }

    @Test("Valid address", arguments: [
        ("BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4", [
            0x00, 0x14, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54,
            0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6
        ]),
        ("tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7", [
            0x00, 0x20, 0x18, 0x63, 0x14, 0x3c, 0x14, 0xc5, 0x16, 0x68, 0x04,
            0xbd, 0x19, 0x20, 0x33, 0x56, 0xda, 0x13, 0x6c, 0x98, 0x56, 0x78,
            0xcd, 0x4d, 0x27, 0xa1, 0xb8, 0xc6, 0x32, 0x96, 0x04, 0x90, 0x32,
            0x62
        ]),
        ("tb1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesrxh6hy", [
            0x00, 0x20, 0x00, 0x00, 0x00, 0xc4, 0xa5, 0xca, 0xd4, 0x62, 0x21,
            0xb2, 0xa1, 0x87, 0x90, 0x5e, 0x52, 0x66, 0x36, 0x2b, 0x99, 0xd5,
            0xe9, 0x1c, 0x6c, 0xe2, 0x4d, 0x16, 0x5d, 0xab, 0x93, 0xe8, 0x64,
            0x33
        ])
    ])
    func validAddress(valid: ValidAddressData) throws {
        let address = valid.address
        let script = Data(valid.script)
        var hrp = "bc"

        let decodedMainnet = try? SegwitAddrCoder.decode(hrp: hrp, addr: address)

        let decodedTestnet: (version: Int, program: Data)?
        if decodedMainnet == nil {
            hrp = "tb"
            decodedTestnet = try SegwitAddrCoder.decode(hrp: hrp, addr: address)
        } else {
            decodedTestnet = .none
        }

        let decoded = try #require(decodedMainnet ?? decodedTestnet)

        // Segwit public key
        let scriptPk = BitcoinScript([decoded.version == 0 ? .zero : .constant(UInt8(decoded.version)), .pushBytes(decoded.program)]).data

        #expect(scriptPk == script, "Decoded script mismatch: \(scriptPk.hex) != \(script.hex)")

        let recoded = try SegwitAddrCoder.encode(hrp: hrp, version: decoded.version, program: decoded.program)
        #expect(!recoded.isEmpty, "Recoded string is empty for \(address)")
    }

    @Test("Invalid address", arguments: [
        "tc1qw508d6qejxtdg4y5r3zarvary0c5xw7kg3g4ty",
        "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5",
        "BC13W508D6QEJXTDG4Y5R3ZARVARY0C5XW7KN40WF2",
        "bc1rw5uspcuh",
        "bc10w508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kw5rljs90",
        "BC1QR508D6QEJXTDG4Y5R3ZARVARYV98GJ9P",
        "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7",
        "bc1zw508d6qejxtdg4y5r3zarvaryvqyzf3du",
        "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3pjxtptv",
        "bc1gmk9yu"
    ])
    func invalidAddress(invalid: String) {
        #expect(throws: Error.self) {
            _ = try SegwitAddrCoder.decode(hrp: "bc", addr: invalid)
        }
        #expect(throws: Error.self) {
            _ = try SegwitAddrCoder.decode(hrp: "tb", addr: invalid)
        }
    }

    @Test("Invalid address encoding", arguments: [
        ("BC", 0, 20),
        ("bc", 0, 21),
        ("bc", 17, 32),
        ("bc", 1, 1),
        ("bc", 16, 41)
    ])
    func invalidAddressEncoding(invalid: InvalidAddressData) {
        let zeroData = Data(repeating: 0x00, count: invalid.programLen)
        #expect(throws: Error.self) {
            let _ = try SegwitAddrCoder.encode(hrp: invalid.hrp, version: invalid.version, program: zeroData)
        }
    }

    @Test("Address encoding decoding performance")
    func addressEncodingDecodingPerfomance() throws {
        let addressToCode = "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4"
        // self.measure { ... }
        for _ in 0..<10 {
            let decoded = try SegwitAddrCoder.decode(hrp: "bc", addr: addressToCode)
            let _ = try SegwitAddrCoder.encode(hrp: "bc", version: decoded.version, program: decoded.program)
        }
    }
}
