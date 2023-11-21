import Foundation
import ECCHelper

func validatePublicKey(_ publicKey: Data) -> Bool {
    let publicKeyPtr = publicKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    return validatePublicKey(publicKeyPtr) != 0
}
