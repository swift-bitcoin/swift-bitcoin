import Foundation
import ECCHelper

func verifyECDSA(sig: Data, msg: Data, publicKey: Data) -> Bool {
    let sigPtr = sig.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let msgPtr = msg.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let publicKeyPtr = publicKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    return (verifyECDSA(sigPtr, sig.count, msgPtr, publicKeyPtr, publicKey.count) != 0)
}
