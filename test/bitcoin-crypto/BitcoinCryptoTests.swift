import Foundation
import Testing
import BitcoinCrypto

struct BitcoinCryptoTests {

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
        let signatureECDSA = try #require(secretKey.sign(message, signatureType: .compact))

        let isECDSASignatureValid = signatureECDSA.verify(message: message, publicKey: publicKey)
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
        let signatureECDSA = try #require(Signature("151756497fb7ad7b910341814aed135e5835b8fa3c6b63132cb36f4b453bdc3c61defc72d99ef44170bd130ef66a9ef4122c96e623d20bff79d0b740c29af2af", type: .compact))

        let isECDSASignatureValid = signatureECDSA.verify(message: message, publicKey: publicKey)
        #expect(isECDSASignatureValid)

        let signatureECDSACopy = try #require(secretKey.sign(message, signatureType: .compact))
        #expect(signatureECDSA == signatureECDSACopy)
    }

    @Test func serializationRoundTrips() async throws {
        let secretKey = SecretKey()
        let secretKey2 = try #require(SecretKey(secretKey.description))
        #expect(secretKey == secretKey2)

        let publicKey = secretKey.publicKey
        let publicKey2 = try #require(PublicKey(publicKey.description))
        #expect(publicKey == publicKey2)
    }

    @Test func schnorr() throws {
        let secretKey = SecretKey()

        let message = "Hello, Bitcoin!"
        let signature = try #require(secretKey.sign(message))

        let publicKey = secretKey.publicKey
        #expect(publicKey.matches(secretKey))
        let valid = publicKey.verify(signature, for: message)
        #expect(valid)

        // Tweak
        let tweak = Data(Hash256.hash(data: "I am Satoshi.".data(using: .utf8)!))
        let tweakedSecretKey = secretKey.tweakXOnly(tweak)
        let signature2 = try #require(tweakedSecretKey.sign(message))

        let tweakedPublicKey = publicKey.tweakXOnly(tweak)
        let valid2 = tweakedPublicKey.verify(signature2, for: message)
        #expect(valid2)

        let valid3 = publicKey.verify(signature2, for: message)
        #expect(!valid3)
    }

    @Test func recoverable() throws {
        let secretKey = SecretKey()

        let message = "Hello, Bitcoin!"
        let signature = try #require(secretKey.sign(message, signatureType: .recoverable))

        let recovered = try #require(signature.recoverPublicKey(from: message))
        #expect(recovered.matches(secretKey))

        let valid = recovered.verify(signature, for: message)
        #expect(valid)

        let publicKey = secretKey.publicKey
        #expect(publicKey == recovered)
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
