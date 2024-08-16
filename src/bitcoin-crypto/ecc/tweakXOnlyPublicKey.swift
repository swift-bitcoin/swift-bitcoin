import Foundation
import LibSECP256k1

/// Internal key is an x-only public key.
public func tweakXOnlyPublicKey(_ publicKeyData: Data, tweak: Data) -> (outputKey: Data, parity: Bool) {

    let publicKeyData = [UInt8](publicKeyData)
    let tweak = [UInt8](tweak)

    var basePoint = secp256k1_xonly_pubkey()

    guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &basePoint, publicKeyData) != 0 else {
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
