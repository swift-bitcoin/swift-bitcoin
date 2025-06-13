import Foundation
import Testing
import BitcoinCrypto

struct BitcoinCryptoTests {

    @Test func basics() async throws {
        let secretKey = SecretKey()

        let pubkey = secretKey.pubkey
        #expect(pubkey.matches(secretKey))

        let pubkeyCopy = PublicKey(secretKey)
        #expect(pubkey == pubkeyCopy)

        let message = "Hello, Bitcoin!"
        let sig = try #require(secretKey.sign(message, sigType: .schnorr))

        let isSignatureValid = pubkey.verify(sig, for: message)
        #expect(isSignatureValid)

        // ECDSA signature
        let sigECDSA = try #require(secretKey.sign(message, sigType: .compact))

        let isECDSASignatureValid = sigECDSA.verify(message: message, pubkey: pubkey)
        #expect(isECDSASignatureValid)
    }

    @Test func deserialization() async throws {
        let secretKey = try #require(SecretKey([0x49, 0xc3, 0xa4, 0x4b, 0xf0, 0xe2, 0xb8, 0x1e, 0x4a, 0x74, 0x11, 0x02, 0xb4, 0x08, 0xe3, 0x11, 0x70, 0x2c, 0x7e, 0x3b, 0xe0, 0x21, 0x5c, 0xa2, 0xc4, 0x66, 0xb3, 0xb5, 0x4d, 0x9c, 0x54, 0x63]))

        let pubkey = try #require(PublicKey([0x02, 0xc8, 0xd2, 0x1f, 0x79, 0x52, 0x9d, 0xee, 0xaa, 0x27, 0x69, 0x19, 0x8d, 0x3d, 0xf6, 0x20, 0x9a, 0x06, 0x4c, 0x99, 0x15, 0xae, 0x55, 0x7f, 0x7a, 0x9d, 0x01, 0xd7, 0x24, 0x59, 0x0d, 0x63, 0x34]))
        #expect(pubkey.matches(secretKey))

        let pubkeyCopy = PublicKey(secretKey)
        #expect(pubkey == pubkeyCopy)

        let message = "Hello, Bitcoin!"
        let sig = try #require(Signature("c211fc6a0d3b89170af26e1bfcc511de813a01e855b862788e1fa576280a7abc202f1bc1535dc51c54ecbae48dcc9b5752ffa4a8852f7d81aafb695f5efd8876", type: .schnorr))

        let isSignatureValid = pubkey.verify(sig, for: message)
        #expect(isSignatureValid)

        let sigCopy = try #require(secretKey.sign(message, sigType: .schnorr))
        #expect(sig == sigCopy)

        // ECDSA signature
        let sigECDSA = try #require(Signature("151756497fb7ad7b910341814aed135e5835b8fa3c6b63132cb36f4b453bdc3c61defc72d99ef44170bd130ef66a9ef4122c96e623d20bff79d0b740c29af2af", type: .compact))

        let isECDSASignatureValid = sigECDSA.verify(message: message, pubkey: pubkey)
        #expect(isECDSASignatureValid)

        let sigECDSACopy = try #require(secretKey.sign(message, sigType: .compact))
        #expect(sigECDSA == sigECDSACopy)
    }

    @Test func serializationRoundTrips() async throws {
        let secretKey = SecretKey()
        let secretKey2 = try #require(SecretKey(secretKey.description))
        #expect(secretKey == secretKey2)

        let pubkey = secretKey.pubkey
        let pubkey2 = try #require(PublicKey(pubkey.description))
        #expect(pubkey == pubkey2)
    }

    @Test func schnorr() throws {
        let secretKey = SecretKey()

        let message = "Hello, Bitcoin!"
        let sig = try #require(secretKey.sign(message, sigType: .schnorr))

        let pubkey = secretKey.pubkey
        #expect(pubkey.matches(secretKey))
        let valid = pubkey.verify(sig, for: message)
        #expect(valid)

        // Tweak
        let tweak = Data(Hash256.hash(data: "I am Satoshi.".data(using: .utf8)!))
        let tweakedSecretKey = secretKey.tweakXOnly(tweak)
        let sig2 = try #require(tweakedSecretKey.sign(message, sigType: .schnorr))

        let tweakedPubkey = pubkey.tweakXOnly(tweak)
        let valid2 = tweakedPubkey.verify(sig2, for: message)
        #expect(valid2)

        let valid3 = pubkey.verify(sig2, for: message)
        #expect(!valid3)
    }

    @Test func recoverable() throws {
        let secretKey = SecretKey()

        let message = "Hello, Bitcoin!"
        let sig = try #require(secretKey.sign(message, sigType: .recoverable))

        let recovered = try #require(sig.recoverPubkey(from: message))
        #expect(recovered.matches(secretKey))

        let valid = recovered.verify(sig, for: message)
        #expect(valid)

        let pubkey = secretKey.pubkey
        #expect(pubkey == recovered)
    }

    @Test func secretKeyDeserialization() async throws {
        let hex = "49c3a44bf0e2b81e4a741102b408e311702c7e3be0215ca2c466b3b54d9c5463"
        let secretKey = try #require(SecretKey(hex))

        let hex2 = secretKey.description
        #expect(hex2 == hex)

        let secretKey2 = try #require(SecretKey(hex))
        #expect(secretKey == secretKey2)
    }
}
