import Foundation
import ECCHelper

func verifySchnorr(sig: Data, msg: Data, publicKey: Data) -> Bool {
    let msgPtr = msg.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let sigPtr = sig.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let publicKeyPtr = publicKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    return (verifySchnorr(msgPtr, sigPtr, publicKeyPtr) != 0)
}
