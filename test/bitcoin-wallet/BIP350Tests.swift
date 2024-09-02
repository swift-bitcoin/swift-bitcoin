import Testing
import Foundation
@testable import BitcoinWallet
import BitcoinCrypto
import BitcoinBase

/// https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki#test-vectors
struct BIP350Tests {

    @Test("Valid checksum", arguments: [
        "A1LQFN3A",
        "a1lqfn3a",
        "an83characterlonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11sg7hg6",
        "abcdef1l7aum6echk45nj3s0wdvt2fg8x9yrzpqzd3ryx",
        "11llllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllludsr8",
        "split1checkupstagehandshakeupstreamerranterredcaperredlc445v",
        "?1v759aa"
    ])
    func validChecksum(valid: String) throws {
        let decoded = try Bech32Decoder(.m).decode(valid)
        #expect(!decoded.hrp.isEmpty, "Empty result.")
        let recoded = Bech32Encoder(.m).encode(decoded.hrp, values: decoded.checksum)
        #expect(valid.lowercased() == recoded.lowercased(), "Roundtrip encoding failed.")
    }

    @Test("Invalid checksum", arguments: [
        (" 1xj0phk", Bech32Decoder.Error.nonPrintableCharacter),
        ("\u{7f}1g6xzxy", .nonPrintableCharacter),
        ("\u{80}1vctc34", .nonPrintableCharacter),
        ("an84characterslonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11d6pts4", .stringLengthExceeded),
        ("qyrz8wqd2c9m", .noChecksumMarker),
        ("1qyrz8wqd2c9m", .incorrectHrpSize),
        ("y1b0jsk6g", .invalidCharacter),
        ("lt1igcx5c0", .invalidCharacter),
        ("in1muywd", .incorrectChecksumSize),
        ("mm1crxm3i", .invalidCharacter),
        ("au1s5cgom", .invalidCharacter),
        ("M1VUXWEZ", .checksumMismatch),
        ("16plkw9", .incorrectHrpSize),
        ("1p2gdwpf", .incorrectHrpSize)
    ])
    func invalidChecksum(encoded: String, reason: Bech32Decoder.Error) {
        #expect(throws: reason) {
            try Bech32Decoder(.m).decode(encoded)
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
        ("bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kt5nd6y", [0x51, 0x28, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6]),
        ("BC1SW50QGDZ25J", [0x60, 0x02, 0x75, 0x1e]),
        ("bc1zw508d6qejxtdg4y5r3zarvaryvaxxpcs", [0x52, 0x10, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23]),
        ("tb1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesrxh6hy", [
            0x00, 0x20, 0x00, 0x00, 0x00, 0xc4, 0xa5, 0xca, 0xd4, 0x62, 0x21,
            0xb2, 0xa1, 0x87, 0x90, 0x5e, 0x52, 0x66, 0x36, 0x2b, 0x99, 0xd5,
            0xe9, 0x1c, 0x6c, 0xe2, 0x4d, 0x16, 0x5d, 0xab, 0x93, 0xe8, 0x64,
            0x33
        ]),
        ("tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c", [0x51, 0x20, 0x00, 0x00, 0x00, 0xc4, 0xa5, 0xca, 0xd4, 0x62, 0x21, 0xb2, 0xa1, 0x87, 0x90, 0x5e, 0x52, 0x66, 0x36, 0x2b, 0x99, 0xd5, 0xe9, 0x1c, 0x6c, 0xe2, 0x4d, 0x16, 0x5d, 0xab, 0x93, 0xe8, 0x64, 0x33]),
        ("bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0", [0x51, 0x20, 0x79, 0xbe, 0x66, 0x7e, 0xf9, 0xdc, 0xbb, 0xac, 0x55, 0xa0, 0x62, 0x95, 0xce, 0x87, 0x0b, 0x07, 0x02, 0x9b, 0xfc, 0xdb, 0x2d, 0xce, 0x28, 0xd9, 0x59, 0xf2, 0x81, 0x5b, 0x16, 0xf8, 0x17, 0x98])
    ])
    func validAddress(address: String, script: [UInt8]) throws {
        let script = Data(script)
        var hrp = "bc"

        var decoded = try? SegwitAddressDecoder(hrp: hrp).decode(address)

        if decoded == nil {
            hrp = "tb"
            decoded = try SegwitAddressDecoder(hrp: hrp).decode(address)
        }

        let scriptPk = BitcoinScript([decoded!.version == 0 ? .zero : .constant(UInt8(decoded!.version)), .pushBytes(decoded!.program)]).data
        #expect(scriptPk == script, "Decoded script mismatch.")

        let recoded = try SegwitAddressEncoder(hrp: hrp, version: decoded!.version).encode(decoded!.program)
        #expect(!recoded.isEmpty, "Decoded string is empty.")
    }

    @Test("Invalid address", arguments: [
        "tc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq5zuyut", // Invalid human-readable part
        "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqh2y7hd", // Invalid checksum (Bech32 instead of Bech32m)
        "tb1z0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqglt7rf", // Invalid checksum (Bech32 instead of Bech32m)
        "BC1S0XLXVLHEMJA6C4DQV22UAPCTQUPFHLXM9H8Z3K2E72Q4K9HCZ7VQ54WELL", // Invalid checksum (Bech32 instead of Bech32m)
        "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kemeawh", // Invalid checksum (Bech32m instead of Bech32)
        "tb1q0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq24jc47", // Invalid checksum (Bech32m instead of Bech32)
        "bc1p38j9r5y49hruaue7wxjce0updqjuyyx0kh56v8s25huc6995vvpql3jow4", //Invalid character in checksum
        "BC130XLXVLHEMJA6C4DQV22UAPCTQUPFHLXM9H8Z3K2E72Q4K9HCZ7VQ7ZWS8R", // Invalid witness version
        "bc1pw5dgrnzv", // Invalid program length (1 byte)
        "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7v8n0nx0muaewav253zgeav", // Invalid program length (41 bytes)
        "BC1QR508D6QEJXTDG4Y5R3ZARVARYV98GJ9P", // Invalid program length for witness version 0 (per BIP141)
        "tb1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq47Zagq", // Mixed case
        "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7v07qwwzcrf", // zero padding of more than 4 bits
        "tb1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vpggkg4j", // Non-zero padding in 8-to-5 conversion
        "bc1gmk9yu", // Empty data section
    ])
    func invalidAddress(invalid: String) {
        #expect {
            _ = try SegwitAddressDecoder(hrp: "bc").decode(invalid)
            _ = try SegwitAddressDecoder(hrp: "tb").decode(invalid)
        } throws: {
            $0 is Bech32Decoder.Error || $0 is SegwitAddressDecoder.Error
        }
    }

    @Test("Invalid address encoding", arguments: [
        ("BC", 0, 20),
        ("bc", 0, 21),
        ("bc", 17, 32),
        ("bc", 1, 1),
        ("bc", 16, 41)
    ])
    func invalidAddressEncoding(hrp: String, version: Int, programLen: Int) {
        #expect(throws: SegwitAddressEncoder.Error.self) {
            let zeroData = Data(repeating: 0x00, count: programLen)
            _ = try SegwitAddressEncoder(hrp: hrp, version: version).encode(zeroData)
        }
    }

    /// From BIP341 [test vectors](https://github.com/bitcoin/bips/blob/master/bip-0341/wallet-test-vectors.json).
    @Test("EC to Address")
    func ecToAddressCommand() throws {
        // Adding 0x02 to the internal public key here to make it a standard public key.
        let publicKey = try #require(PublicKey(compressed: [0x02, 0xd6, 0x88, 0x9c, 0xb0, 0x81, 0x03, 0x6e, 0x0f, 0xae, 0xfa, 0x3a, 0x35, 0x15, 0x7a, 0xd7, 0x10, 0x86, 0xb1, 0x23, 0xb2, 0xb1, 0x44, 0xb6, 0x49, 0x79, 0x8b, 0x49, 0x4c, 0x30, 0x0a, 0x96, 0x1d]))
        let address = TaprootAddress(publicKey).description
        #expect(address == "bc1p2wsldez5mud2yam29q22wgfh9439spgduvct83k3pm50fcxa5dps59h4z5")
    }

    /// From BIP341 [test vectors](https://github.com/bitcoin/bips/blob/master/bip-0341/wallet-test-vectors.json).
    @Test("Script to Addresss")
    func scriptToAddressCommand() throws {
        // Adding 0x02 to the internal public key here to make it a standard public key.
        let publicKeyData = try #require(Data([0x02, 0xf9, 0xf4, 0x00, 0x80, 0x3e, 0x68, 0x37, 0x27, 0xb1, 0x4f, 0x46, 0x38, 0x36, 0xe1, 0xe7, 0x8e, 0x1c, 0x64, 0x41, 0x76, 0x38, 0xaa, 0x06, 0x69, 0x19, 0x29, 0x1a, 0x22, 0x5f, 0x0e, 0x8d, 0xd8]))
        let publicKey = try #require(PublicKey(compressed: publicKeyData))
        let script1Data = try #require(Data([0x20, 0x44, 0xb1, 0x78, 0xd6, 0x4c, 0x32, 0xc4, 0xa0, 0x5c, 0xc4, 0xf4, 0xd1, 0x40, 0x72, 0x68, 0xf7, 0x64, 0xc9, 0x40, 0xd2, 0x0c, 0xe9, 0x7a, 0xbf, 0xd4, 0x4d, 0xb5, 0xc3, 0x59, 0x2b, 0x72, 0xfd, 0xac]))
        let script2Data = try #require(Data([0x07, 0x54, 0x61, 0x70, 0x72, 0x6f, 0x6f, 0x74]))
        let script1 = try #require(BitcoinScript(script1Data, sigVersion: .witnessV1))
        let script2 = try #require(BitcoinScript(script2Data, sigVersion: .witnessV1))
        let address = TaprootAddress(publicKey, scripts: [script1, script2]).description
        #expect(address == "bc1pwl3s54fzmk0cjnpl3w9af39je7pv5ldg504x5guk2hpecpg2kgsqaqstjq")
    }
}
