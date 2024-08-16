import Foundation
import LibSECP256k1

public func checkTapTweak(internalKey internalKeyData: Data, outputKey outputKeyData: Data, tweak: Data, parity: Bool) -> Bool {
    let internalKey = [UInt8](internalKeyData)
    let outputKey = [UInt8](outputKeyData)
    let tweak = [UInt8](tweak)

    var parsedInternalKey = secp256k1_xonly_pubkey()
    guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &parsedInternalKey, internalKey) != 0 else {
        preconditionFailure()
    }

    let result = secp256k1_xonly_pubkey_tweak_add_check(secp256k1_context_static, outputKey, parity ? 1 : 0, &parsedInternalKey, tweak)
    return result != 0
}
