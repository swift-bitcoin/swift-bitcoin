import Foundation
import CSECP256K1

let eccSigningContext: SECP256K1Context = {
    guard let ctx = SECP256K1Context(flags: UInt32(SECP256K1_CONTEXT_NONE)) else {
        preconditionFailure()
    }
    let seed = getRandomBytes(32)
    let ret = ctx.randomize(seed32: seed.span)
    assert((ret != 0))
    return ctx
}()

public func destroyECCSigningContext() {
    eccSigningContext.destroy()
}
