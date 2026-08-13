import Testing
import Foundation
import BitcoinBlockchain
import BitcoinBase

struct SignetTests {

    /// BIP325
    @Test func magicBytes() async throws {

        let defaultSignet = ConsensusParams.signet()
        #expect(defaultSignet.magicBytes == 0x0a03cf40)

        // Taken from the BIP325 example.
        let challengeScriptData: [UInt8] = [0x51, 0x21, 0x03, 0xad, 0x5e, 0x0e, 0xda, 0xd1, 0x8c, 0xb1, 0xf0, 0xfc, 0x0d, 0x28, 0xa3, 0xd4, 0xf1, 0xf3, 0xe4, 0x45, 0x64, 0x03, 0x37, 0x48, 0x9a, 0xbb, 0x10, 0x40, 0x4f, 0x2d, 0x1e, 0x08, 0x6b, 0xe4, 0x30, 0x51, 0xae]
        let challengeScript = try Script(challengeScriptData)
        #expect([UInt8](challengeScript.data) == challengeScriptData)
        let customSignet = ConsensusParams.signet(options: .init(challenge: challengeScriptData))
        #expect(customSignet.magicBytes == 0x7ec653a5)
    }
}
