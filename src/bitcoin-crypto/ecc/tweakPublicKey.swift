import Foundation
import LibSECP256k1

/// BIP32: Used to derive public keys.
public func tweakPublicKey(_ keyData: Data, tweak: Data) -> Data {
    var keyBytes = [UInt8](keyData)
    var tweakBytes = [UInt8](tweak)

    var pubkey: secp256k1_pubkey = .init()
    var result = secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, &keyBytes, keyBytes.count)
    assert(result != 0)

    result = secp256k1_ec_pubkey_tweak_add(secp256k1_context_static, &pubkey, &tweakBytes)
    assert(result != 0)

    let tweakedKey: [UInt8] = .init(unsafeUninitializedCapacity: compressedKeySize) { buf, len in
        len = compressedKeySize
        result = secp256k1_ec_pubkey_serialize(secp256k1_context_static, buf.baseAddress!, &len, &pubkey, UInt32(SECP256K1_EC_COMPRESSED))
        assert(result != 0)
        assert(len == compressedKeySize)

    }
    return Data(tweakedKey)
}
