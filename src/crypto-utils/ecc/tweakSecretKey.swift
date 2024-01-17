import Foundation
import LibSECP256k1

/// BIP32: Used to derive private keys.
public func tweakSecretKey(_ keyData: Data, tweak: Data) -> Data {
    guard let eccSigningContext else {
        preconditionFailure()
    }
    var keyBytes = [UInt8](keyData)
    var tweakBytes = [UInt8](tweak)

    let result = secp256k1_ec_seckey_tweak_add(eccSigningContext, &keyBytes, &tweakBytes)
    assert(result != 0)

    return Data(keyBytes)
}
