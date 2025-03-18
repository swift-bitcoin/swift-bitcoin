enum PSBTOutKeyType: Int, KeyType {

    /// Redeem Script. `PSBT_OUT_REDEEM_SCRIPT` in BIP174.
    ///
    /// The redeemScript for this output if it has one.
    ///
    /// Optional for v0 and v2.
    case redeemScript = 0x00

    /// Witness Script. `PSBT_OUT_WITNESS_SCRIPT` in BIP174.
    ///
    /// The witnessScript for this output if it has one.
    ///
    /// Optional for v0 and v2.
    case witnessScript = 0x01

    /// BIP 32 Derivation Path. `PSBT_OUT_BIP32_DERIVATION` in BIP174.
    ///
    /// The master key fingerprint concatenated with the derivation path of the public key. The derivation path is represented as 32-bit little endian unsigned integer indexes concatenated with each other. Public keys are those needed to spend this output.
    ///
    /// Key data: The public key.
    ///
    /// Optional for v0 and v2.
    case bip32Derivation = 0x02

    /// Proprietary Use Type. `PSBT_OUT_PROPRIETARY` in BIP174.
    ///
    /// Any value data as defined by the proprietary type user.
    ///
    /// Key data: Compact size unsigned integer of the length of the identifier, followed by identifier prefix, followed by a compact size unsigned integer subtype, followed by the key data itself.
    /// Key data format: `<compact size uint identifier length> <bytes identifier> <compact size uint subtype> <bytes subkeydata>`
    ///
    /// Optional for v0 and v2.
    case proprietary = 0xfc
}
