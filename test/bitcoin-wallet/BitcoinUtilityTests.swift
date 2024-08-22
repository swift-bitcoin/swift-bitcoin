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
        let wif = try Wallet.convertToWIF(secretKey: secretKey, compressedPublicKeys: compressedPublicKeys, network: .regtest)
        #expect(wif == "cPuqe8derNHnWuMtRfDUb8CGwuStiEeVAniZTHrmf9yTWyu7n481")

        let (secretKey2, compressedPublicKeys2) = try Wallet.wifToEC(secretKeyWIF: wif)
        #expect(secretKey2 == secretKey)
        #expect(compressedPublicKeys2 == compressedPublicKeys)

        let message = "Hello, Bitcoin!"
        let signature = try Wallet.sign(secretKeyWIF: wif, message: message)
        #expect(signature == "IN97K44jABXPVVQ5dnPo0AcLpmG/Q0b73Yxr6JQvIFtPJJQhshb4NJ2nHjqtRhKIUNGnFGr+tlHxzoOw6xpmJ5I=")

        let result = try Wallet.verify(address: "miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5", signature: signature, message: message)
        #expect(result)
    }
}
