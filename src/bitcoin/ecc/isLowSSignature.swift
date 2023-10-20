import Foundation
import ECCHelper
import LibSECP256k1

func isLowSSignature(_ sigBytes: Data) -> Bool {
    let sigPtr = sigBytes.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }

    return withUnsafeTemporaryAllocation(of: secp256k1_ecdsa_signature.self, capacity: MemoryLayout<secp256k1_ecdsa_signature>.size) { buffer in
        let parsingResult = ecdsa_signature_parse_der_lax(buffer.baseAddress, sigPtr, sigBytes.count)
        precondition(parsingResult != 0, "Invalid DER (lax) encoded signature.")
        let normalizationOccurred = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, .none, buffer.baseAddress!)
        return normalizationOccurred == 0
    }
}
