import Foundation
import ECCHelper
import LibSECP256k1

public func isSignatureLowS(_ extendedSignature: Data) -> Bool {
    let sigBytes = [UInt8](extendedSignature.dropLast())
    var sig = secp256k1_ecdsa_signature()
    guard ecdsa_signature_parse_der_lax(&sig, sigBytes, sigBytes.count) != 0 else {
        preconditionFailure()
    }
    let normalizationOccurred = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, .none, &sig)
    return normalizationOccurred == 0
}
