import Foundation
import ECCHelper
import LibSECP256k1

func getInternalKey(secretKey: Data) -> Data {
    let secretKeyPtr = secretKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let internalKey: [UInt8] = .init(unsafeUninitializedCapacity: 32) { buf, len in
        let successOrError = getInternalKey(eccSigningContext, buf.baseAddress, &len, secretKeyPtr)
        precondition(len == 32, "Key must be 32 bytes long.")
        precondition(successOrError == 1, "Computation of internal key failed.")
    }
    return Data(internalKey)
}

func getInternalKey(publicKey publicKeyData: Data) -> Data {
    let publicKeyBytes = [UInt8](publicKeyData)

    var pubkey: secp256k1_pubkey = .init()
    var result = secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count)
    assert(result != 0)

    var xonlyPubkey: secp256k1_xonly_pubkey = .init()
    var parity = Int32(-1)
    result = secp256k1_xonly_pubkey_from_pubkey(secp256k1_context_static, &xonlyPubkey, &parity, &pubkey)
    assert(result != 0)

    var xonlyPubkeyBytes = [UInt8](repeating: 0, count: 32)
    result = secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &xonlyPubkeyBytes, &xonlyPubkey)
    assert(result != 0)

    return Data(xonlyPubkeyBytes)
}
