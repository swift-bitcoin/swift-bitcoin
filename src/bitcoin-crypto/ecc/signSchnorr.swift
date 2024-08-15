import Foundation
import LibSECP256k1

/// Requires global signing context to be initialized.
public func signSchnorr(msg msgData: Data, secretKey secretKeyData: Data, merkleRoot: Data? = .none, aux auxData: Data?) -> Data {

    let msg = [UInt8](msgData)
    let secretKey = [UInt8](secretKeyData)
    let aux = if let auxData { [UInt8](auxData) } else { [UInt8]?.none }

    var keypair = secp256k1_keypair()
    guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKey) != 0 else {
        preconditionFailure()
    }

    if let merkleRoot {
        var pubKey = secp256k1_xonly_pubkey()
        guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &pubKey, nil, &keypair) != 0 else {
            preconditionFailure()
        }

        var pubKeyBytes = [UInt8](repeating: 0, count: 32)
        guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &pubKeyBytes, &pubKey) != 0 else {
            preconditionFailure()
        }

        let tweak = [UInt8](computeTapTweakHash(internalKey: Data(pubKeyBytes), merkleRoot: merkleRoot))

        guard secp256k1_keypair_xonly_tweak_add(secp256k1_context_static, &keypair, tweak) != 0 else {
            preconditionFailure()
        }
    }

    // Do the signing.
    var sigOut = [UInt8](repeating: 0, count: 64)
    guard secp256k1_schnorrsig_sign32(eccSigningContext, &sigOut, msg, &keypair, aux) != 0 else {
        preconditionFailure()
    }

    // Additional verification step to prevent using a potentially corrupted signature.
    // This public key will be tweaked if a tweak was added to the keypair earlier.
    var pubKeyVerify = secp256k1_xonly_pubkey()
    guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &pubKeyVerify, nil, &keypair) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_schnorrsig_verify(secp256k1_context_static, sigOut, msg, 32, &pubKeyVerify) != 0 else {
        preconditionFailure()
    }

    return Data(sigOut)
}
