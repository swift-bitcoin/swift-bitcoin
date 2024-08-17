import Foundation
import LibSECP256k1

/// There is no such thing as an x-only _secret_ key. This is to differenciate taproot x-only tweaking from BIP32 derivation EC tweaking. This functions is used in BIP341 tests.
///
/// Requires global signing context to be initialized.
/// 
public func tweakXOnlySecretKey(_ secretKeyData: Data, tweak: Data) -> Data {

    let secretKey = [UInt8](secretKeyData)
    let tweak = [UInt8](tweak)

    var keypair = secp256k1_keypair()
    guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKey) != 0 else {
        preconditionFailure()
    }

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
