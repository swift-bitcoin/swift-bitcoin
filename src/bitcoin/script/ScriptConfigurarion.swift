import Foundation

/// Script verification flags represented by configuration options. All flags are intended to be soft forks: the set of acceptable scripts under flags (A | B) is a subset of the acceptable scripts under flag (A).
public struct ScriptConfigurarion {

    public init(strictDER: Bool = true, pushOnly: Bool = true, minimalData: Bool = true, lowS: Bool = true, cleanStack: Bool = true, nullDummy: Bool = true, strictEncoding: Bool = true, payToScriptHash: Bool = true, checkLockTimeVerify: Bool = true, checkSequenceVerify: Bool = true, discourageUpgradableNoOps: Bool = true, constantScriptCode: Bool = true, witness: Bool = true, witnessCompressedPublicKey: Bool = true, minimalIf: Bool = true, nullFail: Bool = true, discourageUpgradableWitnessProgram: Bool = true, taproot: Bool = true, discourageUpgradableTaprootVersion: Bool = true, discourageOpSuccess: Bool = true, discourageUpgradablePublicKeyType: Bool = true) {
        self.strictDER = strictDER || lowS || strictEncoding
        self.pushOnly = pushOnly
        self.minimalData = minimalData
        self.lowS = lowS
        self.cleanStack = cleanStack && payToScriptHash
        self.nullDummy = nullDummy
        self.strictEncoding = strictEncoding
        self.payToScriptHash = payToScriptHash
        self.checkLockTimeVerify = checkLockTimeVerify
        self.checkSequenceVerify = checkSequenceVerify
        self.discourageUpgradableNoOps = discourageUpgradableNoOps
        self.constantScriptCode = constantScriptCode
        self.witness = witness // TODO: Maybe add ` && payToScriptHash`?
        self.witnessCompressedPublicKey = witnessCompressedPublicKey && self.witness
        self.minimalIf = minimalIf
        self.nullFail = nullFail
        self.discourageUpgradableWitnessProgram = discourageUpgradableWitnessProgram && self.witness
        self.taproot = taproot && self.witness
        self.discourageUpgradableTaprootVersion = discourageUpgradableTaprootVersion && self.taproot
        self.discourageOpSuccess = discourageOpSuccess && self.taproot
        self.discourageUpgradablePublicKeyType = discourageUpgradablePublicKeyType && self.taproot
    }

    /// BIP66 (consensus) and BIP62 rule 1 (policy)
    /// Passing a non-strict-DER signature to a checksig operation causes script failure.
    public let strictDER: Bool

    /// BIP62 rule 2
    /// Using a non-push operator in the scriptSig causes script failure.
    public let pushOnly: Bool

    /// BIP62 rule 3-4
    /// Require minimal encodings for all push operations (`OP_0`…`OP_16`, `OP_1NEGATE` where possible, direct  pushes up to 75 bytes, `OP_PUSHDATA` up to 255 bytes, `OP_PUSHDATA2` for anything larger).
    /// Evaluating any other push causes the script to fail (BIP62 rule 3).
    /// In addition, whenever a stack element is interpreted as a number, it must be of minimal length (BIP62 rule 4).
    public let minimalData: Bool

    /// BIP62 rule 5
    /// Passing a non-strict-DER signature or one with S > order/2 to a checksig operation causes script failure.
    public let lowS: Bool

    /// BIP62 rule 6
    /// Require that only a single stack element remains after evaluation. Only to be used with P2SH.
    public let cleanStack: Bool

    /// BIP62 rule 7
    /// Verify dummy stack item consumed by `CHECKMULTISIG` is of zero-length.
    public let nullDummy: Bool

    /// Passing a non-strict-DER signature or one with undefined hashtype to a checksig operation causes script failure.
    /// Evaluating a pubkey that is not (0x04 + 64 bytes) or (0x02 or 0x03 + 32 bytes) by checksig causes script failure.
    /// Not used or intended as a consensus rule.
    public let strictEncoding: Bool

    /// BIP16
    public let payToScriptHash: Bool

    /// BIP65: Evaluate `OP_CHECKLOCKTIMEVERIFY`.
    public let checkLockTimeVerify: Bool

    /// BIP112: Evaluate `OP_CHECKSEQUENCEVERIFY`.
    public let checkSequenceVerify: Bool

    /// Discourage use of NOPs reserved for upgrades (NOP1-10)
    ///
    /// Provided so that nodes can avoid accepting or mining transactions containing executed NOP's whose meaning may change after a soft-fork, thus rendering the script invalid; with this flag set executing discouraged NOPs fails the script.
    /// This verification flag will never be a mandatory flag applied to scripts in a block.
    /// NOPs that are not executed, e.g.  within an unexecuted IF ENDIF block, are *not* rejected.
    /// NOPs that have associated forks to give them new meaning (CLTV, CSV) are not subject to this rule.
    public let discourageUpgradableNoOps: Bool

    /// Making OP_CODESEPARATOR and FindAndDelete fail any non-segwit scripts
    public let constantScriptCode: Bool

    /// BIP141: Verify witness program (all witness versions).
    public let witness: Bool

    /// BIP141: Only compressed public keys are accepted in P2WPKH and P2WSH (See BIP143). Relay/mining policy rule 1.
    public let witnessCompressedPublicKey: Bool

    /// BIP141: The argument of OP_IF/NOTIF in P2WSH must be minimal. Relay/mining policy rule 2.
    public let minimalIf: Bool

    /// BIP141: Signature(s) must be null vector(s) if an OP_CHECKSIG or OP_CHECKMULTISIG is failed (for both pre-segregated witness script and P2WSH. See BIP146). Relay/mining policy rule 3.
    public let nullFail: Bool

    /// Making v2-v16 witness program non-standard.
    public let discourageUpgradableWitnessProgram: Bool

    /// BIP341, BIP342: Taproot/Tapscript validation.
    public let taproot: Bool

    /// Making unknown Taproot leaf versions non-standard.
    public let discourageUpgradableTaprootVersion: Bool

    /// Making unknown `OP_SUCCESS` non-standard.
    public let discourageOpSuccess: Bool

    /// Making unknown public key versions (in BIP342 scripts) non-standard.
    public let discourageUpgradablePublicKeyType: Bool

    /// Standard script verification flags that standard transactions will comply with. However we do not ban/disconnect nodes that forward txs violating the additional (non-mandatory) rules here, to improve forwards and backwards compatability.
    public static let standard = ScriptConfigurarion()

    /// Mandatory script verification flags that all new transactions must comply with for them to be valid. Failing one of these tests may trigger a DoS ban. See `CheckInputScripts()` on Bitcoin Core  for details.
    /// Note that this does not affect consensus validity. See `GetBlockScriptFlags()` for that.
    public static let mandatory = ScriptConfigurarion(
        // strictDER: true, // After DEPLOYMENT_DERSIG (BIP66) buried deployment block (1st)
        pushOnly: false,
        minimalData: false,
        lowS: false,
        cleanStack: false,
        // nullDummy: false, // After DEPLOYMENT_SEGWIT (BIP147) buried deployment block (3rd)
        strictEncoding: false,
        // payToScriptHash: true, // From chain start with 1 block excepted on mainnet
        // checkLockTimeVerify: true, // After DEPLOYMENT_CLTV (BIP65) buried deployment block (2st)
        // checkSequenceVerify: true, // After DEPLOYMENT_CSV (BIP112) buried deployment block (3rd)
        discourageUpgradableNoOps: false,
        constantScriptCode: false,
        // witness: true, // From chain start with 0 blocks excepted
        witnessCompressedPublicKey: false,
        minimalIf: false,
        nullFail: false,
        discourageUpgradableWitnessProgram: false,
        // taproot: true, // From chain start with 1 block excepted on mainnet
        discourageUpgradableTaprootVersion: false,
        discourageOpSuccess: false,
        discourageUpgradablePublicKeyType: false
    )
}
