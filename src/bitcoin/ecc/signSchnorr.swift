import Foundation
import ECCHelper

func signSchnorr(msg: Data, secretKey: Data, merkleRoot: Data?, skipTweak: Bool = false, aux: Data?) -> Data {
    let msgPtr = msg.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let secretKeyPtr = secretKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let merkleRootPtr = merkleRoot?.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let auxPtr = aux?.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    
    let sig: [UInt8] = .init(unsafeUninitializedCapacity: 64) { buf, len in
        let successOrError = signSchnorr(computeTapTweakHashExtern(_:_:_:), buf.baseAddress, &len, msgPtr, merkleRootPtr, skipTweak ? 1 : 0, auxPtr, secretKeyPtr)
        precondition(len == 64, "Signature must be 64 bytes long.")
        precondition(successOrError == 1, "Signing with Schnorr failed.")
    }
    return Data(sig)
}
