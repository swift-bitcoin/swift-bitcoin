import Foundation
import ECCHelper
import LibSECP256k1

/// BIP32: Used to derive private keys.
func tweakSecretKey(_ keyData: Data, tweak: Data) -> Data {
    var keyBytes = [UInt8](keyData)
    var tweakBytes = [UInt8](tweak)

    let result = secp256k1_ec_seckey_tweak_add(secp256k1_context_sign, &keyBytes, &tweakBytes)
    assert(result != 0)

    return Data(keyBytes)
}
