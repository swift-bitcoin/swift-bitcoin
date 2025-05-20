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

    /// Partial Signature. `PSBT_IN_PARTIAL_SIG` in BIP174.
    ///
    /// The signature as would be pushed to the stack from a scriptSig or witness. The signature should be a valid ECDSA signature corresponding to the pubkey that would return true when verified and not a value that would return false or be invalid otherwise (such as a `NULLDUMMY`).
    ///
    /// Key data: The public key which corresponds to this signature.
    ///
    /// Optional for v0 and v2.
    case partialSig = 0x02

    /// Sighash Type. `PSBT_IN_SIGHASH_TYPE` in BIP174.
    ///
    /// The 32-bit unsigned integer specifying the sighash type to be used for this input. Signatures for this input must use the sighash type, finalizers must fail to finalize inputs which have signatures that do not match the specified sighash type. Signers who cannot produce signatures with the sighash type must not provide a signature. Format: `<32-bit little endian uint sighash type>`.
    ///
    /// Optional for v0 and v2.
    case sighashType = 0x03

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

    /// BIP32 Derivation Path. `PSBT_IN_BIP32_DERIVATION` in BIP174.
    ///
    /// The master key fingerprint as defined by BIP 32 concatenated with the derivation path of the public key. The derivation path is represented as 32 bit unsigned integer indexes concatenated with each other. Public keys are those that will be needed to sign this input. Format: `<4 byte fingerprint> <32-bit little endian uint path element>*`.
    ///
    /// Key data: The public key. Format: `<bytes public key>`.
    ///
    /// Optional for v0 and v2.
    case derivationPath = 0x06

    /// Finalized scriptSig. `PSBT_IN_FINAL_SCRIPTSIG` in BIP174.
    ///
    /// The finalized scriptSig contains a fully constructed scriptSig with signatures and any other scripts necessary for the input to pass validation.
    ///
    /// Optional for v0 and v2.
    case finalScriptSig = 0x07

    /// Finalized scriptWitness. `PSBT_IN_FINAL_SCRIPTWITNESS` in BIP174.
    ///
    /// The finalized scriptWitness contains a fully constructed scriptWitness with signatures and any other scripts necessary for the input to pass validation.
    ///
    /// Optional for v0 and v2.
    case finalScriptWitness = 0x08

    /// RIPEMD160 preimage. `PSBT_IN_RIPEMD160` in BIP174.
    ///
    /// The hash preimage, encoded as a byte vector, which must equal the key when run through the RIPEMD160 algorithm.
    ///
    /// Key data: The resulting hash of the preimage. Key data format: `<20-byte hash>`.
    ///
    /// Optional for v0 and v2.
    case ripemd160Preimage = 0x0a

    /// SHA256 preimage. `PSBT_IN_SHA256` in BIP174.
    ///
    /// The hash preimage, encoded as a byte vector, which must equal the key when run through the SHA256 algorithm.
    ///
    /// Key data: The resulting hash of the preimage. Key data format: `<32-byte hash>`.
    ///
    /// Optional for v0 and v2.
    case sha256Preimage = 0x0b

    /// HASH160 preimage. `PSBT_IN_HASH160` in BIP174.
    ///
    /// The hash preimage, encoded as a byte vector, which must equal the key when run through the SHA256 algorithm followed by the RIPEMD160 algorithm.
    ///
    /// Key data: The resulting hash of the preimage. Key data format: `<20-byte hash>`.
    ///
    /// Optional for v0 and v2.
    case hash160Preimage = 0x0c

    /// HASH256 preimage. `PSBT_IN_HASH256` in BIP174.
    ///
    /// The hash preimage, encoded as a byte vector, which must equal the key when run through the SHA256 algorithm twice.
    ///
    /// Key data: The resulting hash of the preimage. Key data format: `<32-byte hash>`.
    ///
    /// Optional for v0 and v2.
    case hash256Preimage = 0x0d

    /// Proprietary Use Type. `PSBT_IN_PROPRIETARY` in BIP174.
    ///
    /// Any value data as defined by the proprietary type user.
    ///
    /// Key data: Compact size unsigned integer of the length of the identifier, followed by identifier prefix, followed by a compact size unsigned integer subtype, followed by the key data itself. Format: `<compact size uint identifier length> <bytes identifier> <compact size uint subtype> <bytes subkeydata>`
    ///
    /// Optional for v0 and v2.
    case proprietary = 0xfc
}
