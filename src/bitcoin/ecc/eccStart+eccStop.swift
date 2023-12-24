import Foundation
import LibSECP256k1
import ECCHelper

public func eccStart() {
    precondition(secp256k1_context_sign == .none)
    guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE)) else {
        assertionFailure()
        return
    }
    let seed = getRandBytes(32)
    let ret = secp256k1_context_randomize(ctx, seed)
    assert((ret != 0))
    secp256k1_context_sign = ctx
}

public func eccStop() {
    let ctx = secp256k1_context_sign
    secp256k1_context_sign = .none
    if let ctx {
        secp256k1_context_destroy(ctx)
    }
}
