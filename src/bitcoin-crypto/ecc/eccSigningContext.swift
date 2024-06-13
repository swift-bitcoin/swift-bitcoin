import Foundation
import LibSECP256k1
import ECCHelper

extension OpaquePointer: @unchecked @retroactive Sendable { }

let secp256k1_context_static = get_static_context()!

let eccSigningContext: OpaquePointer = {
    guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE)) else {
        preconditionFailure()
    }
    let seed = getRandBytes(32)
    let ret = secp256k1_context_randomize(ctx, seed)
    assert((ret != 0))
    return ctx
}()

public func destroyECCSigningContext() {
    secp256k1_context_destroy(eccSigningContext)
}
