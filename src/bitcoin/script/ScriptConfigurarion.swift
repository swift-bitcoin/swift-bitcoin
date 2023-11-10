import Foundation

/// Script verification flags represented by configuration options. All flags are intended to be soft forks: the set of acceptable scripts under flags (A | B) is a subset of the acceptable scripts under flag (A).
public struct ScriptConfigurarion {

    public init(strictDER: Bool = true, pushOnly: Bool = true, lowS: Bool = true, cleanStack: Bool = true, nullDummy: Bool = true, strictEncoding: Bool = true, payToScriptHash: Bool = true, checkLockTimeVerify: Bool = true) {
        self.strictDER = strictDER || lowS || strictEncoding
        self.pushOnly = pushOnly
        self.lowS = lowS
        self.cleanStack = cleanStack
        self.nullDummy = nullDummy
        self.strictEncoding = strictEncoding
        self.payToScriptHash = payToScriptHash || cleanStack
        self.checkLockTimeVerify = checkLockTimeVerify
    }

    /// BIP66 (consensus) and BIP62 rule 1 (policy)
    /// Passing a non-strict-DER signature to a checksig operation causes script failure.
    public var strictDER = true

    /// BIP62 rule 2
    /// Using a non-push operator in the scriptSig causes script failure.
    public var pushOnly = true

    /// BIP62 rule 5
    /// Passing a non-strict-DER signature or one with S > order/2 to a checksig operation causes script failure.
    public var lowS = true {
        didSet {
            strictDER = strictDER || lowS || strictEncoding
        }
    }

    /// BIP62 rule 6
    /// Require that only a single stack element remains after evaluation.
    public var cleanStack = true {
        didSet {
            payToScriptHash = payToScriptHash || cleanStack
        }
    }

    /// BIP62 rule 7
    /// Verify dummy stack item consumed by `CHECKMULTISIG` is of zero-length.
    public var nullDummy = true

    /// Passing a non-strict-DER signature or one with undefined hashtype to a checksig operation causes script failure.
    /// Evaluating a pubkey that is not (0x04 + 64 bytes) or (0x02 or 0x03 + 32 bytes) by checksig causes script failure.
    /// Not used or intended as a consensus rule.
    public var strictEncoding = true {
        didSet {
            strictDER = strictDER || lowS || strictEncoding
        }
    }

    /// BIP16
    public var payToScriptHash = true

    /// BIP65: Evaluate `OP_CHECKLOCKTIMEVERIFY`.
    public var checkLockTimeVerify = true

    /// BIP68 `LOCKTIME_VERIFY_SEQUENCE`
    public var lockTimeSequence = true

    /// BIP112: Evaluate `OP_CHECKSEQUENCEVERIFY`.
    public var checkSequenceVerify = true

    /// Standard script verification flags that standard transactions will comply with. However we do not ban/disconnect nodes that forward txs violating the additional (non-mandatory) rules here, to improve forwards and backwards compatability.
    public static let standard = ScriptConfigurarion()

    /// Mandatory script verification flags that all new transactions must comply with for them to be valid. Failing one of these tests may trigger a DoS ban. See `CheckInputScripts()` on Bitcoin Core  for details.
    /// Note that this does not affect consensus validity. See `GetBlockScriptFlags()` for that.
    public static let mandatory = ScriptConfigurarion(
        pushOnly: false,
        lowS: false,
        cleanStack: false,
        nullDummy: false,
        strictEncoding: false
    )
}
