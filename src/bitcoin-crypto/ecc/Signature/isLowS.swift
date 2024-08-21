import Foundation
import ECCHelper
import LibSECP256k1

// TODO: Move this function into Signature struct somehow.
public func isLowS(extendedSignature: Data) -> Bool {
    let extendedSignature = [UInt8](extendedSignature)
    let signatureBytes = [UInt8](extendedSignature.dropLast())
    var signature = secp256k1_ecdsa_signature()
    guard ecdsa_signature_parse_der_lax(&signature, signatureBytes, signatureBytes.count) != 0 else {
        preconditionFailure()
    }
    let normalizationOccurred = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, .none, &signature)
    return normalizationOccurred == 0
}
