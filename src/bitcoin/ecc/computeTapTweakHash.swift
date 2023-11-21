import Foundation
import ECCHelper
import CryptoKit

func computeTapTweakHash(xOnlyPublicKey: Data, merkleRoot: Data?) -> Data {
    var joined = xOnlyPublicKey
    if let merkleRoot {
        joined += merkleRoot
    }
    return taggedHash(tag: "TapTweak", payload: joined)
}

func computeTapTweakHashExtern(_ tweakOut: UnsafeMutablePointer<UInt8>!, _ xOnlyPubKey32: UnsafePointer<UInt8>!, _ merkleRoot32: UnsafePointer<UInt8>!) {
    let xOnlyPubKeyData = Data(bytes: xOnlyPubKey32, count: 32)
    let merkleRootData: Data? = merkleRoot32 == .none ? .none : Data(bytes: merkleRoot32, count: 32)
    let resultData = computeTapTweakHash(xOnlyPublicKey: xOnlyPubKeyData, merkleRoot: merkleRootData)
    resultData.copyBytes(to: tweakOut, from: 0 ..< 32)
}
