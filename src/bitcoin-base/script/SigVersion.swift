/// Signature version or effectively the version of _SCRIPT_ which affects how some operations are decoded and executed.
public enum SigVersion: String, Sendable {

    /// Legacy scripts.
    case base

    /// BIP141
    case witnessV0

    /// BIP341
    case witnessV1
}
