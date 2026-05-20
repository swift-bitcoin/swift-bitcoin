/// Standard output types plus a case for a non-standard output.
public enum OutputType {
    /// Non-standard output.
    case nonStandard

    /// Pay to public key (P2PK).
    case pubkey

    /// Pay to public key hash (P2PKH).
    case pubkeyHash

    /// Pay to script hash (P2SH).
    case scriptHash

    /// Pay to multi-signature (legacy).
    case multisig

    /// Null data (data carrier output), i.e. `OP_RETURN`.
    case nullData

    /// Pay to Anchor (P2A).
    ///
    /// BIP433
    case anchor

    /// Segregated witness version 0, pay to public key hash.
    case witnessV0KeyHash

    /// Segregated witness version 0, pay to script hash.
    case witnessV0ScriptHash

    /// Segregated witness version 1, taproot.
    case witnessV1Taproot

    /// Segregated witness version unknown.
    case witnessUnknown
}
