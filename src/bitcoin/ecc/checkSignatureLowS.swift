import Foundation
import ECCHelper
import LibSECP256k1

func checkSignatureLowS(_ extendedSignature: Data) throws {
    let sigBytes = extendedSignature.dropLast()
    let sigBytesPtr = sigBytes.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    var sig = secp256k1_ecdsa_signature()
    withUnsafeMutablePointer(to: &sig) {
        let result = ecdsa_signature_parse_der_lax($0, sigBytesPtr, sigBytes.count)
        precondition(result != 0, "Invalid DER (lax) encoded signature.")
    }
    let normalizationOccurred = withUnsafeMutablePointer(to: &sig) {
        secp256k1_ecdsa_signature_normalize(secp256k1_context_static, .none, $0)
    }
    if normalizationOccurred != 0 {
        throw ScriptError.nonLowSSignature
    }
}
