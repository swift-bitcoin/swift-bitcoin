/// Signature version or effectively the version of _SCRIPT_ which affects how some operations are decoded and executed.
public enum SigVersion: String {
    case base,
         witnessV0, // BIP141
         witnessV1 // BIP341
}
