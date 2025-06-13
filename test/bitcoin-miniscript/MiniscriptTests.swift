import Testing
import Foundation
import BitcoinBase
import BitcoinCrypto
import BitcoinMiniscript

struct MiniscriptTests {

    let key1 = PublicKey(compressed: Data([0x03, 0x70, 0x0d, 0xa8, 0x3d, 0x6c, 0x7e, 0x20, 0xc8, 0xa7, 0x99, 0x65, 0xa6, 0xb1, 0xc3, 0x5b, 0x97, 0x6a, 0x02, 0x5a, 0x85, 0x0f, 0x72, 0xdd, 0x95, 0x36, 0x37, 0x4d, 0x10, 0x7b, 0x58, 0xbe, 0x4a]))!
    let key2 = PublicKey(compressed: Data([0x02, 0x79, 0xe2, 0x1d, 0x05, 0x07, 0xe0, 0xcf, 0x26, 0x56, 0xfd, 0x73, 0xbe, 0xab, 0xf7, 0xc7, 0x48, 0x7b, 0xc0, 0x31, 0xda, 0x1d, 0x45, 0x81, 0x2d, 0x61, 0xe9, 0x6a, 0xa4, 0x01, 0xdf, 0x14, 0xab]))!
    let key3 = PublicKey(compressed: Data([0x02, 0xe3, 0x07, 0x34, 0xde, 0xd7, 0xff, 0x76, 0x5f, 0x5c, 0x11, 0x15, 0x31, 0x55, 0xfb, 0x38, 0x6c, 0x75, 0xbb, 0x6b, 0x38, 0x99, 0xd4, 0xa5, 0x0f, 0x90, 0xe3, 0xe1, 0xbe, 0xc3, 0x2a, 0xb2, 0x43]))!
    let key1Hex = "03700da83d6c7e20c8a79965a6b1c35b976a025a850f72dd9536374d107b58be4a"
    let key2Hex = "0279e21d0507e0cf2656fd73beabf7c7487bc031da1d45812d61e96aa401df14ab"
    let key3Hex = "02e30734ded7ff765f5c11153155fb386c75bb6b3899d4a50f90e3e1bec32ab243"
    let key2Hash = "bfebfddcc81414d6997cd3c12872006d64604b07"

    @Test("A single key") func singleKey() throws {
        // The Miniscript
        let exp = PK(key1)

        #expect(exp.description == "pk(\(key1Hex))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIG ")

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bondemusk; script len: 35; max ops: 1; max stack size: 2
        #expect(miniscript.evaluated.binaryData.count == 36)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.o))
        #expect(miniscript.properties.mods.contains(.n))
        #expect(miniscript.properties.mods.contains(.d))
        #expect(miniscript.properties.mods.contains(.u))
        #expect(miniscript.properties.k)
    }

    @Test("One of two keys (equally likely)") func oneOfTwoLikely() throws {
        // The Miniscript
        let exp = OrB(PK(key1), S~PK(key2))

        #expect(exp.description == "or_b(pk(\(key1Hex)),s:pk(\(key2Hex)))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIG OP_SWAP \(key2Hex) OP_CHECKSIG OP_BOOLOR ")

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bdemusk; script len: 72; max ops: 4; max stack size: 3
        #expect(miniscript.evaluated.binaryData.count == 73)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.d))
        #expect(miniscript.properties.mods.contains(.u))
        #expect(miniscript.properties.k)
    }

    @Test("One of two keys (one likely, one unlikely)") func oneOfTwoUnlikely() throws {
        // The Miniscript
        let exp = OrD(PK(key1),PKH(key2))

        #expect(exp.description == "or_d(pk(\(key1Hex)),pkh(\(key2Hex)))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIG OP_IFDUP OP_NOTIF OP_DUP OP_HASH160 \(key2Hash) OP_EQUALVERIFY OP_CHECKSIG OP_ENDIF ")

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bdemusk; script len: 63; max ops: 8; max stack size: 4
        #expect(miniscript.evaluated.binaryData.count == 64)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.d))
        #expect(miniscript.properties.mods.contains(.u))
        #expect(miniscript.properties.k)
    }

    @Test("A user and a 2FA service need to sign off, but after 90 days the user alone is enough") func userPlu2FA() throws {
        // The Miniscript
        let exp = AndV(V~PK(key1), OrD(PK(key2), Older(12960)))

        #expect(exp.description == "and_v(v:pk(\(key1Hex)),or_d(pk(\(key2Hex)),older(12960)))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIGVERIFY \(key2Hex) OP_CHECKSIG OP_IFDUP OP_NOTIF a032 OP_CHECKSEQUENCEVERIFY OP_ENDIF ")

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bnfmsk; script len: 77; max ops: 6; max stack size: 3
        #expect(miniscript.evaluated.binaryData.count == 78)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.n))
        #expect(miniscript.properties.k)
    }

    @Test("A 3-of-3 that turns into a 2-of-3 after 90 days") func threeOfThree() throws {
        // The Miniscript
        let exp = Thresh(3, PK(key1), S~PK(key2), S~PK(key3), SLN~Older(12960))

        #expect(exp.description == "thresh(3,pk(\(key1Hex)),s:pk(\(key2Hex)),s:pk(\(key3Hex)),sln:older(12960))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIG OP_SWAP \(key2Hex) OP_CHECKSIG OP_ADD OP_SWAP \(key3Hex) OP_CHECKSIG OP_ADD OP_SWAP OP_IF 0 OP_ELSE a032 OP_CHECKSEQUENCEVERIFY OP_0NOTEQUAL OP_ENDIF OP_ADD OP_3 OP_EQUAL ") // "3" swapped for "OP_3"

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bdmusk; script len: 122; max ops: 15; max stack size: 5
        #expect(miniscript.evaluated.binaryData.count == 123)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.d))
        #expect(miniscript.properties.mods.contains(.u))
        #expect(miniscript.properties.k)
    }

    @Test("The BOLT #3 to_local policy") func boltToLocalPolicy() throws {
        // The Miniscript
        let exp = AndOr(PK(key1), Older(1008), PK(key2)) // key1: local; key2: revokation

        #expect(exp.description == "andor(pk(\(key1Hex)),older(1008),pk(\(key2Hex)))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIG OP_NOTIF \(key2Hex) OP_CHECKSIG OP_ELSE f003 OP_CHECKSEQUENCEVERIFY OP_ENDIF ")

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bdemsk; script len: 77; max ops: 6; max stack size: 3
        #expect(miniscript.evaluated.binaryData.count == 78)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.d))
        #expect(miniscript.properties.k)
    }

    @Test("The BOLT #3 offered HTLC policy") func boltOfferedHTLC() throws {
        let key2HashData = Data([0xff, 0xeb, 0xfd, 0xdc, 0xc8, 0x14, 0x14, 0xd6, 0x99, 0x7c, 0xd3, 0xc1, 0x28, 0x72, 0x00, 0x6d, 0x64, 0x60, 0x4b, 0x07])

        // key_revocation = key1
        // key_remote = key2
        // key_local = key3
        // H = hash key2

        // The Miniscript
        let exp = T~OrC(PK(key1), AndV(V~PK(key2), OrC(PK(key3), V~Hash160(key2HashData))))

        #expect(exp.description == "t:or_c(pk(\(key1Hex)),and_v(v:pk(\(key2Hex)),or_c(pk(\(key3Hex)),v:hash160(\(key2HashData.hex)))))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIG OP_NOTIF \(key2Hex) OP_CHECKSIGVERIFY \(key3Hex) OP_CHECKSIG OP_NOTIF OP_SIZE 20 OP_EQUALVERIFY OP_HASH160 \(key2HashData.hex) OP_EQUALVERIFY OP_ENDIF OP_ENDIF OP_1 ")

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bfmusk; script len: 137; max ops: 11; max stack size: 5
        #expect(miniscript.evaluated.binaryData.count == 138)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.u))
        #expect(miniscript.properties.k)
    }

    @Test("The BOLT #3 received HTLC policy") func boltReceivedHTLC() throws {
        let key2HashData = Data([0xbf, 0xeb, 0xfd, 0xdc, 0xc8, 0x14, 0x14, 0xd6, 0x99, 0x7c, 0xd3, 0xc1, 0x28, 0x72, 0x00, 0x6d, 0x64, 0x60, 0x4b, 0x07])

        // The Miniscript
        let exp = AndOr(PK(key1), OrI(AndV(V~PKH(key2), Hash160(key2HashData)), Older(1008)), PK(key3))
        // remote key: key1; local key: key2; revocation:key3

        #expect(exp.description == "andor(pk(\(key1Hex)),or_i(and_v(v:pkh(\(key2Hex)),hash160(\(key2Hash))),older(1008)),pk(\(key3Hex)))")
        let asm = Script(exp.compiled).asm()
        #expect(asm == "\(key1Hex) OP_CHECKSIG OP_NOTIF \(key3Hex) OP_CHECKSIG OP_ELSE OP_IF OP_DUP OP_HASH160 \(key2Hash) OP_EQUALVERIFY OP_CHECKSIGVERIFY OP_SIZE 20 OP_EQUALVERIFY OP_HASH160 \(key2Hash) OP_EQUAL OP_ELSE f003 OP_CHECKSEQUENCEVERIFY OP_ENDIF OP_ENDIF ")

        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)

        // Bdmsk; script len: 132; max ops: 17; max stack size: 6
        #expect(miniscript.evaluated.binaryData.count == 133)
        #expect(miniscript.properties.type == .B)
        #expect(miniscript.properties.mods.contains(.d))
        #expect(miniscript.properties.k)
    }
}
