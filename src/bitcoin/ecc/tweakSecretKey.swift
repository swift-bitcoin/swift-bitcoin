import Foundation
import LibSECP256k1

/// BIP32: Used to derive private keys.
func tweakSecretKey(_ keyData: Data, tweak: Data) -> Data {
    var keyBytes = [UInt8](keyData)
    var tweakBytes = [UInt8](tweak)

    let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
    let result = secp256k1_ec_seckey_tweak_add(ctx, &keyBytes, &tweakBytes)
    assert(result != 0)

    return Data(keyBytes)
}
