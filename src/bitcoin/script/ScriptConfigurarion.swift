import Foundation

/// Script verification flags represented by configuration options. All flags are intended to be soft forks: the set of acceptable scripts under flags (A | B) is a subset of the acceptable scripts under flag (A).
public struct ScriptConfigurarion {

    /// BIP62 rule 7
    /// Verify dummy stack item consumed by `CHECKMULTISIG` is of zero-length.
    public var checkNullDummy = true

    /// BIP62 rule 5
    /// Passing a non-strict-DER signature or one with S > order/2 to a checksig operation causes script failure.
    public var checkLowS = true

    /// BIP62 rule 1
    /// Passing a non-strict-DER signature to a checksig operation causes script failure.
    public var checkStrictDER = true

    /// Passing a non-strict-DER signature or one with undefined hashtype to a checksig operation causes script failure.
    /// Evaluating a pubkey that is not (0x04 + 64 bytes) or (0x02 or 0x03 + 32 bytes) by checksig causes script failure.
    /// Not used or intended as a consensus rule.
    public var checkStrictEncoding = true

    /// Standard script verification flags that standard transactions will comply with. However we do not ban/disconnect nodes that forward txs violating the additional (non-mandatory) rules here, to improve forwards and backwards compatability.
    public static let standard = ScriptConfigurarion()

    /// Mandatory script verification flags that all new transactions must comply with for them to be valid. Failing one of these tests may trigger a DoS ban. See `CheckInputScripts()` on Bitcoin Core  for details.
    /// Note that this does not affect consensus validity. See `GetBlockScriptFlags()` for that.
    public static let mandatory = ScriptConfigurarion(
        checkNullDummy: false,
        checkLowS: false,
        checkStrictDER: false,
        checkStrictEncoding: false
    )
}
