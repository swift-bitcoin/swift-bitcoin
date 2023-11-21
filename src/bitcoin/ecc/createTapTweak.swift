import Foundation
import ECCHelper

func createTapTweak(publicKey: Data, merkleRoot: Data?) -> (tweakedKey: Data, parity: Bool) {
    let publicKeyPtr = publicKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let merkleRootPtr = merkleRoot?.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    var parity: Int32 = -1
    let tweakedKey: [u_char] = .init(unsafeUninitializedCapacity: 32) { buf, len in
        let successOrError = createTapTweak(computeTapTweakHashExtern(_:_:_:), buf.baseAddress, &len, &parity, publicKeyPtr, merkleRootPtr)
        precondition(len == 32, "Tweaked key must be 32 bytes long.")
        precondition(successOrError == 1, "Could not generate tweak.")
    }
    if parity != 0 && parity != 1 {
        fatalError("Could not calculate parity.")
    }
    return (
        tweakedKey: Data(tweakedKey),
        parity: parity == 1
    )
}
