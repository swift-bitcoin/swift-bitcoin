enum PSBTInKeyType: Int, KeyType {

    /// Non-Witness UTXO .`PSBT_IN_NON_WITNESS_UTXO` in BIP174.
    ///
    /// The transaction in network serialization format the current input spends from. This should be present for inputs that spend non-segwit outputs and can be present for inputs that spend segwit outputs. An input can have both `PSBT_IN_NON_WITNESS_UTXO` and `PSBT_IN_WITNESS_UTXO`.
    ///
    /// Optional for v0 and v2.
    case nonWitnessUTXO = 0x00

    /// Witness UTXO.`PSBT_IN_WITNESS_UTXO` in BIP174.
    ///
    /// The entire transaction output in network serialization which the current input spends from. This should only be present for inputs which spend segwit outputs, including P2SH embedded ones. An input can have both `PSBT_IN_NON_WITNESS_UTXO` and `PSBT_IN_WITNESS_UTXO`. Format: `<64-bit little endian int amount> <compact size uint scriptPubKeylen> <bytes scriptPubKey>`
    ///
    /// Optional for v0 and v2.
    case witnessUTXO = 0x01

    /// Redeem Script. `PSBT_IN_REDEEM_SCRIPT` in BIP174.
    ///
    /// The redeemScript for this input if it has one.
    ///
    /// Optional for v0 and v2.
    case redeemScript = 0x04

    /// Witness Script. `PSBT_IN_WITNESS_SCRIPT` in BIP174.
    ///
    /// The witnessScript for this input if it has one.
    ///
    /// Optional for v0 and v2.
    case witnessScript = 0x05

    /// Proprietary Use Type. `PSBT_IN_PROPRIETARY` in BIP174.
    ///
    /// Any value data as defined by the proprietary type user.
    ///
    /// Key data: Compact size unsigned integer of the length of the identifier, followed by identifier prefix, followed by a compact size unsigned integer subtype, followed by the key data itself.
    /// Key data format: `<compact size uint identifier length> <bytes identifier> <compact size uint subtype> <bytes subkeydata>`
    ///
    /// Optional for v0 and v2.
    case proprietary = 0xfc
}
