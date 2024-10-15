import Testing
import BitcoinCrypto
import Foundation
import BitcoinBase
import BitcoinWallet

struct BitcoinUtilityTests {

    /// Test signing messages
    @Test("Message signing")
    func messageSigning() async throws {
        let secretKey = try #require(SecretKey(Data([0x45, 0x85, 0x1e, 0xe2, 0x66, 0x2f, 0x0c, 0x36, 0xf4, 0xfd, 0x2a, 0x7d, 0x53, 0xa0, 0x8f, 0x7b, 0x06, 0xc7, 0xab, 0xfd, 0x61, 0x95, 0x3c, 0x52, 0x16, 0xcc, 0x39, 0x7c, 0x4f, 0x2c, 0xae, 0x8c])))
        let compressedPublicKeys = true
        let wif = secretKey.toWIF(compressedPublicKeys: compressedPublicKeys, mainnet: false)
        #expect(wif == "cPuqe8derNHnWuMtRfDUb8CGwuStiEeVAniZTHrmf9yTWyu7n481")

        var metadataOptional = SecretKey.WIFMetadata?.none
        let secretKey2 = try #require(SecretKey(wif: wif, metadata: &metadataOptional))
        let metadata = try #require(metadataOptional)
        #expect(secretKey2 == secretKey)
        #expect(!metadata.isMainnet)
        #expect(metadata.compressedPublicKeys == compressedPublicKeys)

        let message = "Hello, Bitcoin!"
        let messageData = try #require(message.data(using: .utf8))
        let signature = Signature(messageData: messageData, secretKey: secretKey2, type: .recoverable, recoverCompressedKeys: metadata.compressedPublicKeys)

        #expect(signature.base64 == "IN97K44jABXPVVQ5dnPo0AcLpmG/Q0b73Yxr6JQvIFtPJJQhshb4NJ2nHjqtRhKIUNGnFGr+tlHxzoOw6xpmJ5I=")

        let address = "miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5"
        // Decode P2PKH address
        let addressDecoded = try #require(BitcoinAddress(address))
        let result = if let publicKey = signature.recoverPublicKey(messageData: messageData) {
            Data(Hash160.hash(data: publicKey.data)) == addressDecoded.hash
        } else {
            false
        }
        #expect(result)
    }

    /// Verifies fix for bug #263
    @Test func addressDecoding() throws {
        let publicKeyData = try #require(Data(hex: "029a3865b2488e2fee75336d1048c1d0795a088368a0caa4adc076425c90227bc3"))
        let publicKey = try #require(PublicKey(publicKeyData))
        let address1 = BitcoinAddress(publicKey, mainnet: true)
        let addressText1 = address1.description
        #expect(addressText1 == "1MMgabnpMVKTnYXwJfupDJRpWNJmUay8cP")
        let address2 = try #require(BitcoinAddress(addressText1))
        #expect(address1 == address2)
    }
}
