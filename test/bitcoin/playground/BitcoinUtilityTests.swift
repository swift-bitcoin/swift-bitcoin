import XCTest
import Bitcoin

final class BitcoinUtilityTests: XCTestCase {

    /// Test signing messages
    func testMessageSigning() async throws {
        let secretKey = Data([0x45, 0x85, 0x1e, 0xe2, 0x66, 0x2f, 0x0c, 0x36, 0xf4, 0xfd, 0x2a, 0x7d, 0x53, 0xa0, 0x8f, 0x7b, 0x06, 0xc7, 0xab, 0xfd, 0x61, 0x95, 0x3c, 0x52, 0x16, 0xcc, 0x39, 0x7c, 0x4f, 0x2c, 0xae, 0x8c])
        let compressedPublicKey = true
        let wif = try Wallet.convertToWIF(secretKey: secretKey, compressedPublicKey: compressedPublicKey, network: .regtest)
        XCTAssertEqual(wif, "cPuqe8derNHnWuMtRfDUb8CGwuStiEeVAniZTHrmf9yTWyu7n481")

        let (secretKey2, compressedPublicKey2) = try Wallet.wifToEC(secretKey: wif)
        XCTAssertEqual(secretKey2, secretKey)
        XCTAssertEqual(compressedPublicKey2, compressedPublicKey)

        let message = "Hello, Bitcoin!"
        let signature = try Wallet.sign(secretKey: wif, message: message)
        XCTAssertEqual(signature, "IN97K44jABXPVVQ5dnPo0AcLpmG/Q0b73Yxr6JQvIFtPJJQhshb4NJ2nHjqtRhKIUNGnFGr+tlHxzoOw6xpmJ5I=")

        let result = try Wallet.verify(address: "miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5", signature: signature, message: message)
        XCTAssert(result)
    }
}
