import Testing
import Foundation
@testable import BitcoinPSBT
import BitcoinBase

struct AuxiliaryTests {

    @Test func derivationPath() throws {
        let path = DerivationPath(fingerprint: Int(UInt32.max), indices: [0, Int(UInt32.max / 2), Int(UInt32.max)])
        let data = path.binaryData
        let path2 = try DerivationPath(binaryData: data)
        #expect(path == path2)
    }
}
