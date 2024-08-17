import Foundation
import LibSECP256k1

/// Produces an ECDSA signature that is compact and from which a public key can be recovered.
/// 
/// Requires global signing context to be initialized.
public func signRecoverable(message: Data, secretKey secretKeyData: Data, compressedPublicKey: Bool) -> Data {

    precondition(secretKeyData.count == secretKeySize)

    let hash = [UInt8](messageHash(message))
    let secretKey = [UInt8](secretKeyData)

    var rsig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_sign_recoverable(eccSigningContext, &rsig, hash, secretKey, secp256k1_nonce_function_rfc6979, nil) != 0 else {
        preconditionFailure()
    }

    var sig = [UInt8](repeating: 0, count: recoverableSignatureSize)
    var rec: Int32 = -1
    guard secp256k1_ecdsa_recoverable_signature_serialize_compact(eccSigningContext, &sig[1], &rec, &rsig) != 0 else {
        preconditionFailure()
    }

    precondition(rec >= 0 && rec < UInt8.max - 27 - (compressedPublicKey ? 4 : 0))
    sig[0] = UInt8(27 + rec + (compressedPublicKey ? 4 : 0))

    // Additional verification step to prevent using a potentially corrupted signature

    var epk = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &epk, secretKey) != 0 else {
        preconditionFailure()
    }

    var rpk = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &rpk, &rsig, hash) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ec_pubkey_cmp(secp256k1_context_static, &epk, &rpk) == 0 else {
        preconditionFailure()
    }

    return Data(sig)
}
