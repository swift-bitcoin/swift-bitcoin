import BitcoinBase
import BitcoinPSBT
import BitcoinWallet
import Foundation
import Testing

struct AuxiliaryTests {
    @Test func derivationPath() throws {
        let path = DerivationPath(
            fingerprint: Int(UInt32.max), indices: [0, Int((UInt32.max / 2) - 1), Int(UInt32.max / 4)])
        let data = path.data
        let path2 = try DerivationPath(data)
        #expect(path == path2)
    }
}
