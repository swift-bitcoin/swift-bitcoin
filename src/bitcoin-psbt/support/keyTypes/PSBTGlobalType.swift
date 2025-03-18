protocol KeyType: CaseIterable, RawRepresentable where RawValue == Int { }

enum PSBTGlobalKeyType: Int, KeyType {

    /// Unsigned Transaction. `PSBT_GLOBAL_UNSIGNED_TX` in BIP174.
    ///
    /// The transaction in network serialization. The scriptSigs and witnesses for each input must be empty. The transaction must be in the old serialization format (without witnesses).
    ///
    /// Required for v0. Required exclusion on v2.
    case unsignedTx = 0x00

    /// Extended Public Key. `PSBT_GLOBAL_XPUB` in BIP174.
    ///
    /// The master key fingerprint as defined by BIP 32 concatenated with the derivation path of the public key. The derivation path is represented as 32-bit little endian unsigned integer indexes concatenated with each other. The number of 32 bit unsigned integer indexes must match the depth provided in the extended public key. Format: `<4 byte fingerprint> <32-bit little endian uint path element>*`
    ///
    /// Key data: The 78 byte serialized extended public key as defined by BIP 32. Extended public keys are those that can be used to derive public keys used in the inputs and outputs of this transaction. It should be the public key at the highest hardened derivation index so that the unhardened child keys used in the transaction can be derived.
    ///
    /// Optional for v0 and v2.
    case xpub = 0x01

    /// PSBT Version Number. `PSBT_GLOBAL_VERSION` in BIP174.
    ///
    /// The 32-bit little endian unsigned integer representing the version number of this PSBT. If omitted, the version number is 0.
    ///
    /// Optional for v0. Required for v2.
    case version = 0xfb

    /// Proprietary Use Type. `PSBT_GLOBAL_PROPRIETARY` in BIP174.
    ///
    /// Any value data as defined by the proprietary type user.
    ///
    /// Key data: Compact size unsigned integer of the length of the identifier, followed by identifier prefix, followed by a compact size unsigned integer subtype, followed by the key data itself.
    /// Key data format: `<compact size uint identifier length> <bytes identifier> <compact size uint subtype> <bytes subkeydata>`
    ///
    /// Optional for v0 and v2.
    case proprietary = 0xfc
}
