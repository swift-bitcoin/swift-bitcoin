import Foundation
import Testing
import BitcoinCrypto

struct Base58Tests {

    /// Verifies fix for bug #263
    @Test func base58Decoding() throws {
        let data = Data(hex: "00df4bdfc1f4a0eb9d08a22598c69a15c9989adc86")!
        let encoded = Base58Encoder(withChecksum: false).encode(data)
        #expect(encoded == "147S3jgXCFakX9TNMFWS9KQPWcpU5")
        let decoded = Base58Decoder(withChecksum: false).decode(encoded)!
        #expect(decoded == data)
    }
}
