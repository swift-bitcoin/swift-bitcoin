import Foundation
import LibSECP256k1
import ECCHelper // For `ecdsa_signature_parse_der_lax()`

/// Verifies a signature using a public key.
public func verifyECDSA(sig sigData: Data, msg msgData: Data, publicKeyData: Data) -> Bool {

    guard !publicKeyData.isEmpty else { return false }

    let sigBytes = [UInt8](sigData)
    let publicKeyBytes = [UInt8](publicKeyData)
    let msgBytes = [UInt8](msgData)

    var sig = secp256k1_ecdsa_signature()
    guard ECCHelper.ecdsa_signature_parse_der_lax(&sig, sigBytes, sigBytes.count) != 0 else {
        preconditionFailure()
    }

    var sigNorm = secp256k1_ecdsa_signature()
    secp256k1_ecdsa_signature_normalize(secp256k1_context_static, &sigNorm, &sig)

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0 else {
        preconditionFailure()
    }

    return secp256k1_ecdsa_verify(secp256k1_context_static, &sigNorm, msgBytes, &pubkey) != 0
}

/// Verifies a signature using a secret key instead of a public key. Requires global signing context to be initialized. Currently unused. Untested. Unpublished.
func verifyECDSA(sig sigData: Data, msg msgData: Data, secretKeyData: Data) -> Bool {

    let sigBytes = [UInt8](sigData)
    let secretKeyBytes = [UInt8](secretKeyData)
    let msgBytes = [UInt8](msgData)

    var sig = secp256k1_ecdsa_signature()
    guard secp256k1_ecdsa_signature_parse_der(secp256k1_context_static, &sig, sigBytes, sigBytes.count) != 0 else {
        preconditionFailure()
    }

    var sigNorm = secp256k1_ecdsa_signature()
    secp256k1_ecdsa_signature_normalize(secp256k1_context_static, &sigNorm, &sig)

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    return secp256k1_ecdsa_verify(secp256k1_context_static, &sigNorm, msgBytes, &pubkey) != 0
}
