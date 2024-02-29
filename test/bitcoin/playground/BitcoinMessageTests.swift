import XCTest
@testable import Bitcoin
@testable import bcnode
import BitcoinCrypto

final class BitcoinMessageTests: XCTestCase {

    func testMalformed() throws {
        let data = Data([0xfa, 0xbf, 0xb5, 0xda, 0x77, 0x74, 0x78, 0x69, 0x64, 0x72, 0x65, 0x6c, 0x61, 0x79, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5d, 0xf6, 0xe0, 0xe2])
        let parsed = BitcoinMessage(data)
        XCTAssertNotNil(parsed)
    }
}
