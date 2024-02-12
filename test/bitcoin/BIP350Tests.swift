import XCTest
@testable import Bitcoin
import BitcoinCrypto

fileprivate typealias InvalidChecksum = (bech32: String, error: Bech32.DecodingError)
fileprivate typealias ValidAddressData = (address: String, script: [UInt8])
fileprivate typealias InvalidAddressData = (hrp: String, version: Int, programLen: Int)

/// https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki#test-vectors
class BIP350Tests: XCTestCase {

    private let _validChecksum: [String] = [
        "A1LQFN3A",
        "a1lqfn3a",
        "an83characterlonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11sg7hg6",
        "abcdef1l7aum6echk45nj3s0wdvt2fg8x9yrzpqzd3ryx",
        "11llllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllludsr8",
        "split1checkupstagehandshakeupstreamerranterredcaperredlc445v",
        "?1v759aa"
    ]

    private let _invalidChecksum: [InvalidChecksum] = [
        (" 1xj0phk", Bech32.DecodingError.nonPrintableCharacter),
        ("\u{7f}1g6xzxy", Bech32.DecodingError.nonPrintableCharacter),
        ("\u{80}1vctc34", Bech32.DecodingError.nonPrintableCharacter),
        ("an84characterslonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11d6pts4", Bech32.DecodingError.stringLengthExceeded),
        ("qyrz8wqd2c9m", Bech32.DecodingError.noChecksumMarker),
        ("1qyrz8wqd2c9m", Bech32.DecodingError.incorrectHrpSize),
        ("y1b0jsk6g", Bech32.DecodingError.invalidCharacter),
        ("lt1igcx5c0", Bech32.DecodingError.invalidCharacter),
        ("in1muywd", Bech32.DecodingError.incorrectChecksumSize),
        ("mm1crxm3i", Bech32.DecodingError.invalidCharacter),
        ("au1s5cgom", Bech32.DecodingError.invalidCharacter),
        ("M1VUXWEZ", Bech32.DecodingError.checksumMismatch),
        ("16plkw9", Bech32.DecodingError.incorrectHrpSize),
        ("1p2gdwpf", Bech32.DecodingError.incorrectHrpSize)
    ]

    private let _invalidAddress: [String] = [
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
    ]

    private let _validAddressData: [ValidAddressData] = [
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
        ("bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kt5nd6y", [UInt8](Data([0x51, 0x28, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6]))),
        ("BC1SW50QGDZ25J", [UInt8](Data([0x60, 0x02, 0x75, 0x1e]))),
        ("bc1zw508d6qejxtdg4y5r3zarvaryvaxxpcs", [UInt8](Data([0x52, 0x10, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23]))),
        ("tb1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesrxh6hy", [
            0x00, 0x20, 0x00, 0x00, 0x00, 0xc4, 0xa5, 0xca, 0xd4, 0x62, 0x21,
            0xb2, 0xa1, 0x87, 0x90, 0x5e, 0x52, 0x66, 0x36, 0x2b, 0x99, 0xd5,
            0xe9, 0x1c, 0x6c, 0xe2, 0x4d, 0x16, 0x5d, 0xab, 0x93, 0xe8, 0x64,
            0x33
        ]),
        ("tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c", [UInt8](Data([0x51, 0x20, 0x00, 0x00, 0x00, 0xc4, 0xa5, 0xca, 0xd4, 0x62, 0x21, 0xb2, 0xa1, 0x87, 0x90, 0x5e, 0x52, 0x66, 0x36, 0x2b, 0x99, 0xd5, 0xe9, 0x1c, 0x6c, 0xe2, 0x4d, 0x16, 0x5d, 0xab, 0x93, 0xe8, 0x64, 0x33]))),
        ("bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0", [UInt8](Data([0x51, 0x20, 0x79, 0xbe, 0x66, 0x7e, 0xf9, 0xdc, 0xbb, 0xac, 0x55, 0xa0, 0x62, 0x95, 0xce, 0x87, 0x0b, 0x07, 0x02, 0x9b, 0xfc, 0xdb, 0x2d, 0xce, 0x28, 0xd9, 0x59, 0xf2, 0x81, 0x5b, 0x16, 0xf8, 0x17, 0x98])))
    ]

    private let _invalidAddressData: [InvalidAddressData] = [
        ("BC", 0, 20),
        ("bc", 0, 21),
        ("bc", 17, 32),
        ("bc", 1, 1),
        ("bc", 16, 41)
    ]

    func testValidChecksum() {
        for valid in _validChecksum {
            do {
                let decoded = try Bech32.decode(valid)
                XCTAssertFalse(decoded.hrp.isEmpty, "Empty result for \"\(valid)\"")
                XCTAssert(decoded.isBech32m)
                let recoded = Bech32.encode(decoded.hrp, values: decoded.checksum, useBech32m: true)
                XCTAssert(valid.lowercased() == recoded.lowercased(), "Roundtrip encoding failed: \(valid) != \(recoded)")
            } catch {
                XCTFail("Error decoding \(valid): \(error.localizedDescription)")
            }
        }
    }

    func testInvalidChecksum() {
        for invalid in _invalidChecksum {
            let checksum = invalid.bech32
            let reason = invalid.error
            do {
                let decoded = try Bech32.decode(checksum)
                //XCTAssertFalse(decoded.isBech32m)
                XCTFail("Successfully decoded an invalid checksum \(checksum): \(decoded.checksum.hex)")
            } catch let error as Bech32.DecodingError {
                XCTAssert(errorsEqual(error, reason), "Decoding error mismatch, got \(error.localizedDescription), expected \(reason.localizedDescription)")
            } catch {
                XCTFail("Invalid error occured: \(error.localizedDescription)")
            }
        }
    }

    func testValidAddress() {
        for valid in _validAddressData {
            let address = valid.address
            let script = Data(valid.script)
            var hrp = "bc"

            var decoded = try? SegwitAddrCoder.decode(hrp: hrp, addr: address)

            do {
                if decoded == nil {
                    hrp = "tb"
                    decoded = try SegwitAddrCoder.decode(hrp: hrp, addr: address)
                }
            } catch {
                XCTFail("Failed to decode \(address)")
                continue
            }

            let scriptPk = segwitPublicKey(version: decoded!.version, program: decoded!.program)
            XCTAssert(scriptPk == script, "Decoded script mismatch: \(scriptPk.hex) != \(script.hex)")

            do {
                let recoded = try SegwitAddrCoder.encode(hrp: hrp, version: decoded!.version, program: decoded!.program)
                XCTAssertFalse(recoded.isEmpty, "Recoded string is empty for \(address)")
            } catch {
                XCTFail("Roundtrip encoding failed for \"\(address)\" with error: \(error.localizedDescription)")
            }
        }
    }

    func testInvalidAddress() {
        for invalid in _invalidAddress {
            do {
                let decoded = try SegwitAddrCoder.decode(hrp: "bc", addr: invalid)
                XCTFail("Successfully decoded an invalid address \(invalid) for hrp \"bc\": \(decoded.program.hex)")
            } catch {
                // OK here :)
            }

            do {
                let decoded = try SegwitAddrCoder.decode(hrp: "tb", addr: invalid)
                XCTFail("Successfully decoded an invalid address \(invalid) for hrp \"tb\": \(decoded.program.hex)")
            } catch {
                // OK again
            }
        }
    }

    func testInvalidAddressEncoding() {
        for invalid in _invalidAddressData {
            do {
                let zeroData = Data(repeating: 0x00, count: invalid.programLen)
                let wtf = try SegwitAddrCoder.encode(hrp: invalid.hrp, version: invalid.version, program: zeroData)
                XCTFail("Successfully encoded zero bytes data \(wtf)")
            } catch {
                // the way it should go
            }
        }
    }

    /// From BIP341 [test vectors](https://github.com/bitcoin/bips/blob/master/bip-0341/wallet-test-vectors.json).
    func testECToAddressCommand() throws {
        // Adding 0x02 to the internal public key here to make it a standard public key.
        let address = try Wallet.getAddress(publicKey: "02d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d", sigVersion: .witnessV1, network: .main)
        XCTAssertEqual(address, "bc1p2wsldez5mud2yam29q22wgfh9439spgduvct83k3pm50fcxa5dps59h4z5")
    }

    /// From BIP341 [test vectors](https://github.com/bitcoin/bips/blob/master/bip-0341/wallet-test-vectors.json).
    func testScriptToAddressCommand() throws {
        // Adding 0x02 to the internal public key here to make it a standard public key.
        let address = try Wallet.getAddress(scripts: ["2044b178d64c32c4a05cc4f4d1407268f764c940d20ce97abfd44db5c3592b72fdac", "07546170726f6f74"], publicKey: "02f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd8", sigVersion: .witnessV1, network: .main)
        XCTAssertEqual(address, "bc1pwl3s54fzmk0cjnpl3w9af39je7pv5ldg504x5guk2hpecpg2kgsqaqstjq")
    }

    private func segwitPublicKey(version: Int, program: Data) -> Data {
        BitcoinScript([version == 0 ? .zero : .constant(UInt8(version)), .pushBytes(program)]).data
    }

    private func errorsEqual(_ lhs: Bech32.DecodingError, _ rhs: Bech32.DecodingError) -> Bool {
        switch lhs {
        case .checksumMismatch:
            return rhs == .checksumMismatch
        case .incorrectChecksumSize:
            return rhs == .incorrectChecksumSize
        case .incorrectHrpSize:
            return rhs == .incorrectHrpSize
        case .invalidCase:
            return rhs == .invalidCase
        case .invalidCharacter:
            return rhs == .invalidCharacter
        case .noChecksumMarker:
            return rhs == .noChecksumMarker
        case .nonUTF8String:
            return rhs == .nonUTF8String
        case .stringLengthExceeded:
            return rhs == .stringLengthExceeded
        case .nonPrintableCharacter:
            return rhs == .nonPrintableCharacter
        }
    }
}
