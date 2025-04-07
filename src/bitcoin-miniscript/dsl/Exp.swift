/// B, K or V
public protocol ExpBKV: MiniscriptExp { }

/// "B" Base expressions. These take their inputs from the top of the stack. When satisfied, they push a nonzero value of up to 4 bytes onto the stack. When dissatisfied, they push an exact 0 onto the stack (if dissatisfaction without aborting is possible at all). This type is used for most expressions, and required for the top level expression. An example is `older(n) = <n> CHECKSEQUENCEVERIFY`.
public protocol ExpB: ExpBKV { }

/// "K" Key expressions. They again take their inputs from the top of the stack, but instead of verifying a condition directly they always push a public key onto the stack, for which a signature is still required to satisfy the expression. A "K" can be converted into a "B" using the c: wrapper (CHECKSIG). An example is `pk_h(key) = DUP HASH160 <Hash160(key)> EQUALVERIFY`
public protocol ExpK: ExpBKV { }

/// "V" Verify expressions. Like "B", these take their inputs from the top of the stack. Upon satisfaction however, they continue without pushing anything. They cannot be dissatisfied (will abort instead). A "V" can be obtained using the v: wrapper on a "B" expression, or by combining other "V" expressions using `and_v`, `or_i`, `or_c`, or `andor`. An example is `v:pk(key) = <key> CHECKSIGVERIFY`.
public protocol ExpV: ExpBKV { }

/// "W" Wrapped expressions. They take their inputs from one below the top of the stack, and push a nonzero (in case of satisfaction) or zero (in case of dissatisfaction) either on top of the stack, or one below. So for example a 3-input "W" would take the stack "A B C D E F" and turn it into "A B F 0" or "A B 0 F" in case of dissatisfaction, and "A B F n" or "A B n F" in case of satisfaction (with n a nonzero value). Every "W" is either `s:B` (`SWAP B`) or `a:B` (`TOALTSTACK B FROMALTSTACK`). An example is `s:pk(key) = SWAP <key> CHECKSIG`.
public protocol ExpW: MiniscriptExp { }
