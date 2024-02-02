import XCTest
import Bitcoin

final class BitcoinUtilityTests: XCTestCase {

    /// Test signing messages
    func testMessageSigning() async throws {
        let secretKey = Data(hex: "45851ee2662f0c36f4fd2a7d53a08f7b06c7abfd61953c5216cc397c4f2cae8c")!
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
