import Testing
import BitcoinCrypto
import Foundation
import BitcoinBase
import BitcoinWallet

struct AddressTests {

    @Test func roundTrips() async throws {
        let secretKey = try #require(SecretKey(Data([0x45, 0x85, 0x1e, 0xe2, 0x66, 0x2f, 0x0c, 0x36, 0xf4, 0xfd, 0x2a, 0x7d, 0x53, 0xa0, 0x8f, 0x7b, 0x06, 0xc7, 0xab, 0xfd, 0x61, 0x95, 0x3c, 0x52, 0x16, 0xcc, 0x39, 0x7c, 0x4f, 0x2c, 0xae, 0x8c])))
        let pubkey = secretKey.pubkey

        let legacyAddress = LegacyAddress(pubkey)
        let legacyAddressText = legacyAddress.description
        let legacyAddressAgain = try #require(LegacyAddress(legacyAddressText))
        #expect(legacyAddress == legacyAddressAgain)
        let anyAddressLegacy = try #require(Address(legacyAddressText))
        let anyAddressLegacyText = anyAddressLegacy.description
        #expect(anyAddressLegacyText == legacyAddressText)
        let anyAddressLegacyAgain = try #require(Address(anyAddressLegacyText))
        #expect(anyAddressLegacy == anyAddressLegacyAgain)

        let segwitAddress = SegwitAddress(pubkey)
        let segwitAddressText = segwitAddress.description
        let segwitAddressAgain = try #require(SegwitAddress(segwitAddressText))
        #expect(segwitAddress == segwitAddressAgain)
        let anyAddressSegwit = try #require(Address(segwitAddressText))
        let anyAddressSegwitText = anyAddressSegwit.description
        #expect(anyAddressSegwitText == segwitAddressText)
        let anyAddressSegwitAgain = try #require(Address(anyAddressSegwitText))
        #expect(anyAddressSegwit == anyAddressSegwitAgain)
        #expect(anyAddressLegacy != anyAddressSegwit)

        let internalKey = secretKey.xOnlyPubkey
        // The resulting output key will have odd-y parity in this case, but TaprootAddress will store it with even-y because it only will encode its x-only representation.
        #expect(internalKey.taprootOutputKey().hasOddY)
        let taprootAddress = TaprootAddress(internalKey)

        let taprootAddressText = taprootAddress.description
        let taprootAddressAgain = try #require(TaprootAddress(taprootAddressText))
        #expect(taprootAddress == taprootAddressAgain)
        let anyAddressTaproot = try #require(Address(taprootAddressText))
        let anyAddressTaprootText = anyAddressTaproot.description
        #expect(anyAddressTaprootText == taprootAddressText)
        let anyAddressTaprootAgain = try #require(Address(anyAddressTaprootText))
        #expect(anyAddressTaproot == anyAddressTaprootAgain)
        #expect(anyAddressLegacy != anyAddressTaproot)
    }
}
