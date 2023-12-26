import Foundation
import LibSECP256k1

var eccSigningContext: OpaquePointer? = .none

public func eccStart() {
    precondition(eccSigningContext == .none)
    guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE)) else {
        assertionFailure()
        return
    }
    let seed = getRandBytes(32)
    let ret = secp256k1_context_randomize(ctx, seed)
    assert((ret != 0))
    eccSigningContext = ctx
}

public func eccStop() {
    let ctx = eccSigningContext
    eccSigningContext = .none
    if let ctx {
        secp256k1_context_destroy(ctx)
    }
}
