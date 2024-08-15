import Foundation
import LibSECP256k1

/// Internal key is an x-only public key.
public func createTapTweak(internalKey internalKeyData: Data, merkleRoot: Data) -> (outputKey: Data, parity: Bool) {

    let internalKey = [UInt8](internalKeyData)
    let tweak = [UInt8](computeTapTweakHash(internalKey: internalKeyData, merkleRoot: merkleRoot))

    var basePoint = secp256k1_xonly_pubkey()

    guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &basePoint, internalKey) != 0 else {
        preconditionFailure()
    }

    var out = secp256k1_pubkey()
    guard secp256k1_xonly_pubkey_tweak_add(secp256k1_context_static, &out, &basePoint, tweak) != 0 else {
        preconditionFailure()
    }

    var parity: Int32 = -1
    var outXOnly = secp256k1_xonly_pubkey()
    guard secp256k1_xonly_pubkey_from_pubkey(secp256k1_context_static, &outXOnly, &parity, &out) != 0 else {
        preconditionFailure()
    }

    var xOnlyPubkeyBytes = [UInt8](repeating: 0, count: 32)
    guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &xOnlyPubkeyBytes, &outXOnly) != 0 else {
        preconditionFailure()
    }

    return (
        outputKey: Data(xOnlyPubkeyBytes),
        parity: parity == 1
    )
}

/// Requires global signing context to be initialized.
public func createTapTweak(secretKey secretKeyData: Data, merkleRoot: Data) -> Data {

    let secretKey = [UInt8](secretKeyData)

    var keypair = secp256k1_keypair()
    guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKey) != 0 else {
        preconditionFailure()
    }

    // Find out the internal key
    var pubKey = secp256k1_xonly_pubkey()
    guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &pubKey, nil, &keypair) != 0 else {
        preconditionFailure()
    }

    var xOnlyPubkeyBytes = [UInt8](repeating: 0, count: 32)
    guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &xOnlyPubkeyBytes, &pubKey) != 0 else {
        preconditionFailure()
    }

    // Calculate the tweak hash
    let tweak = [UInt8](computeTapTweakHash(internalKey: Data(xOnlyPubkeyBytes), merkleRoot: merkleRoot))

    // Tweak the keypair
    guard secp256k1_keypair_xonly_tweak_add(secp256k1_context_static, &keypair, tweak) != 0 else {
        preconditionFailure()
    }

    var tweakedSecretKey = [UInt8](repeating: 0, count: 32)
    guard secp256k1_keypair_sec(secp256k1_context_static, &tweakedSecretKey, &keypair) != 0 else {
        preconditionFailure()
    }

    // Result output
    return Data(tweakedSecretKey)
}
