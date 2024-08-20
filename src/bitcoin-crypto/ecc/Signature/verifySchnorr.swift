import Foundation
import LibSECP256k1

public func verifySchnorr(sig sigData: Data, msg msgData: Data, publicKey: PublicKey) -> Bool {

    precondition(sigData.count == 64)
    precondition(msgData.count == 32)
    // precondition(publicKeyData.count == 32)

    // guard !publicKeyData.isEmpty else { return false }

    let sigBytes = [UInt8](sigData)
    let publicKeyBytes = [UInt8](publicKey.xOnlyData.x)
    let msgBytes = [UInt8](msgData)

    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonlyPubkey, publicKeyBytes) != 0 else {
        return false
    }

    return secp256k1_schnorrsig_verify(secp256k1_context_static, sigBytes, msgBytes, msgBytes.count, &xonlyPubkey) != 0
}
