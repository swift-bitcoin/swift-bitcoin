import Foundation
import Testing
import BitcoinCrypto

/// Keep this variable `true` to avoid delays with regular testing.
private let performanceTestsDisabled = false

extension Tag {
    @Tag static var performanceTest: Self
}

struct Base58Tests {

    /// Verifies fix for bug #263
    @Test func base58Decoding() throws {
        let data = Data(hex: "00df4bdfc1f4a0eb9d08a22598c69a15c9989adc86")!
        let encoded = Base58Encoder(withChecksum: false).encode(data)
        #expect(encoded == "147S3jgXCFakX9TNMFWS9KQPWcpU5")
        let decoded = Base58Decoder(withChecksum: false).decode(encoded)!
        #expect(decoded == data)
    }

    @Test(.tags(.performanceTest), .disabled(if: performanceTestsDisabled))
    func measureEncoding() throws {
        let data = Data(hex: "00df4bdfc1f4a0eb9d08a22598c69a15c9989adc86")!
        let clock = ContinuousClock()
        let encodingTime = clock.measure {
            for _ in 0 ..< 100_000 {
                _ = Base58Encoder(withChecksum: false).encode(data)
            }
        }
        print("Encoding Time: \(encodingTime)")
        let encoded = Base58Encoder(withChecksum: false).encode(data)
        let decodingTime = clock.measure {
            for _ in 0 ..< 100_000 {
                _ = Base58Decoder(withChecksum: false).decode(encoded)
            }
        }
        print("Decoding Time: \(decodingTime)")
        let legacyEncodingTime = clock.measure {
            for _ in 0 ..< 100_000 {
                _ = Base58EncoderLegacy(withChecksum: false).encode(data)
            }
        }
        print("Legacy encoding Time: \(legacyEncodingTime)")
        let encodedLegacy = Base58EncoderLegacy(withChecksum: false).encode(data)
        let legacyDecodingTime = clock.measure {
            for _ in 0 ..< 100_000 {
                _ = Base58DecoderLegacy(withChecksum: false).decode(encodedLegacy)
            }
        }
        print("Legacy decoding Time: \(legacyDecodingTime)")
    }
}
