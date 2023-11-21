import Foundation
import ECCHelper

func createSecretKeyTapTweak(secretKey: Data, merkleRoot: Data?) -> Data {
    let secretKeyPtr = secretKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let merkleRootPtr = merkleRoot?.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let tweakedKey: [u_char] = .init(unsafeUninitializedCapacity: 32) { buf, len in
        let successOrError = createSecretKeyTapTweak(computeTapTweakHashExtern(_:_:_:), buf.baseAddress, &len, secretKeyPtr, merkleRootPtr)
        precondition(len == 32, "Tweaked key must be 32 bytes long.")
        precondition(successOrError == 1, "Could not generate tweak.")
    }
    return Data(tweakedKey)
}
