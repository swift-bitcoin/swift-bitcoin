import Foundation
import ECCHelper

func checkTapTweak(publicKey: Data, tweakedKey: Data, merkleRoot: Data?, parity: Bool) -> Bool {
    let publicKeyPtr = publicKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let tweakedKeyPtr = tweakedKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let merkleRootPtr = merkleRoot?.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    return (checkTapTweak(computeTapTweakHashExtern(_:_:_:), publicKeyPtr, tweakedKeyPtr, merkleRootPtr, parity ? 1 : 0) != 0)
}
