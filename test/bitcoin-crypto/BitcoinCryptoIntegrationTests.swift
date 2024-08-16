import Foundation
import Testing
import BitcoinCrypto

struct BitcoinCryptoIntegrationTests {

    @Test func basics() async throws {
        let secretKey = SecretKey()

        let publicKey = secretKey.publicKey
        #expect(publicKey.matches(secretKey))

        let publicKeyCopy = PublicKey(secretKey)
        #expect(publicKey == publicKeyCopy)

        let message = "Hello, Bitcoin!"
        let signature = try #require(secretKey.sign(message))

        let isSignatureValid = publicKey.verify(signature, for: message)
        #expect(isSignatureValid)

        // ECDSA signature
        let signatureECDSA = try #require(secretKey.sign(message, signatureType: .ecdsa))

        let isECDSASignatureValid = signatureECDSA.verify(for: message, using: publicKey)
        #expect(isECDSASignatureValid)
    }

    @Test func deserialization() async throws {
        let secretKey = try #require(SecretKey("49c3a44bf0e2b81e4a741102b408e311702c7e3be0215ca2c466b3b54d9c5463"))

        let publicKey = try #require(PublicKey("02c8d21f79529deeaa2769198d3df6209a064c9915ae557f7a9d01d724590d6334"))
        #expect(publicKey.matches(secretKey))

        let publicKeyCopy = PublicKey(secretKey)
        #expect(publicKey == publicKeyCopy)

        let message = "Hello, Bitcoin!"
        let signature = try #require(Signature("c211fc6a0d3b89170af26e1bfcc511de813a01e855b862788e1fa576280a7abc202f1bc1535dc51c54ecbae48dcc9b5752ffa4a8852f7d81aafb695f5efd8876"))

        let isSignatureValid = publicKey.verify(signature, for: message)
        #expect(isSignatureValid)

        let signatureCopy = try #require(secretKey.sign(message))
        #expect(signature == signatureCopy)

        // ECDSA signature
        let signatureECDSA = try #require(Signature("151756497fb7ad7b910341814aed135e5835b8fa3c6b63132cb36f4b453bdc3c61defc72d99ef44170bd130ef66a9ef4122c96e623d20bff79d0b740c29af2af", type: .ecdsa))

        let isECDSASignatureValid = signatureECDSA.verify(for: message, using: publicKey)
        #expect(isECDSASignatureValid)

        let signatureECDSACopy = try #require(secretKey.sign(message, signatureType: .ecdsa))
        #expect(signatureECDSA == signatureECDSACopy)
    }

    @Test func serializationRoundTrips() async throws {
        let secretKey = SecretKey()
        let secretKey2 = try #require(SecretKey(secretKey.description))
        #expect(secretKey == secretKey2)

        let publicKey = secretKey.publicKey
        let publicKey2 = try #require(PublicKey(publicKey.description))
        #expect(publicKey == publicKey2)

        let publicKey3 = try #require(PublicKey(publicKey.description(.uncompressed), format: .uncompressed))
        #expect(publicKey == publicKey3)

        let publicKey5 = try #require(PublicKey(publicKey.description, format: .none))
        #expect(publicKey == publicKey5)

        let publicKey6 = try #require(PublicKey(publicKey.description(.uncompressed), format: .none))
        #expect(publicKey == publicKey6)
    }
}
