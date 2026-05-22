import BitcoinBase

enum PolicyConstants {

    /// See ``BitcoinBase/Script/defaultPermitBareMultisig``.
    ///
    /// `DEFAULT_PERMIT_BAREMULTISIG`
    static let defaultPermitBareMultisig = true

    /// See ``BitcoinBase/Script/defaultAcceptDatacarrier``.
    ///
    /// `DEFAULT_ACCEPT_DATACARRIER`
    static let defaultAcceptDatacarrier = true

    /// See ``BitcoinBase/Transaction/maxStandardWeight``.
    ///
    /// `MAX_STANDARD_TX_WEIGHT`
    static let maxStandardWeight = 400_000

    /// See ``BitcoinBase/Transaction/maxDustOutputs``.
    ///
    /// `MAX_DUST_OUTPUTS_PER_TX`
    static let maxDustOutputs = 1

    /// See ``BitcoinBase/Transaction/dustRelayFee``.
    ///
    /// `DUST_RELAY_TX_FEE`
    static let dustRelayFee = 3000

    /// See ``BitcoinBase/Transaction/minStandardNonWitnessSize``.
    ///
    /// `MIN_STANDARD_TX_NONWITNESS_SIZE`
    static let minStandardNonWitnessTransactionSize = 65

    /// See ``BitcoinBase/Script/maxStandardInputScriptSize``.
    ///
    /// `MAX_STANDARD_SCRIPTSIG_SIZE`
    static let maxStandardInputScriptSize = 1650

    /// See ``BitcoinBase/Script/maxOpReturnRelay``.
    ///
    /// `MAX_OP_RETURN_RELAY`
    static let maxOpReturnRelay = maxStandardWeight / ConsensusConstants.witnessScaleFactor

    /// See ``BitcoinBase/Script/maxP2SHSigops``.
    ///
    /// `MAX_P2SH_SIGOPS`
    static let maxP2SHSigops = 15

    /// See ``BitcoinBase/Transaction/maxStandardSigopsCost``.
    ///
    /// `MAX_STANDARD_TX_SIGOPS_COST`
    static let maxStandardTransactionSigopsCost = ConsensusConstants.maxBlockSigopsCost / 5

    /// See ``BitcoinBase/Transaction/maxLegacySigops``.
    ///
    /// `MAX_TX_LEGACY_SIGOPS`
    static let maxTransactionLegacySigops = 2_500

    // MARK: - P2WSH limits (witness standardness)

    /// See ``BitcoinBase/Transaction/Witness/maxP2WSHScriptSize``.
    ///
    /// `MAX_STANDARD_P2WSH_SCRIPT_SIZE`
    static let maxP2WSHScriptSize = 3600 // bytes

    /// See ``BitcoinBase/Transaction/Witness/maxP2WSHStackItems``.
    ///
    /// `MAX_STANDARD_P2WSH_STACK_ITEMS`
    static let maxP2WSHStackItems = 100

    /// See ``BitcoinBase/Transaction/Witness/maxP2WSHStackItemSize``.
    ///
    /// `MAX_STANDARD_P2WSH_STACK_ITEM_SIZE`
    static let maxP2WSHStackItemSize = 80 // bytes

    /// See ``BitcoinBase/Transaction/Witness/maxTapscriptStackItemSize``.
    ///
    /// `MAX_STANDARD_TAPSCRIPT_STACK_ITEM_SIZE`
    static let maxTapscriptStackItemSize = 80 // bytes

    /// See ``BitcoinBase/Transaction/Input/standardLocktimeVerifyOption``.
    ///
    /// `STANDARD_LOCKTIME_VERIFY_FLAGS`
    static let standardLocktimeVerifyOption = ConsensusConstants.locktimeVerifySequence
}

/// Policy.
public extension Transaction {

    /// Maximum standard weight.
    static let maxStandardWeight = PolicyConstants.maxStandardWeight

    /// Maximum number of ephemeral dust outputs allowed.
    static let maxDustOutputs = PolicyConstants.maxDustOutputs

    /// Min feerate for defining dust.
    ///
    /// Changing the dust limit changes which transactions are standard and should be done with care and ideally rarely. It makes sense to only increase the dust limit after prior releases were already not creating outputs below the new threshold.
    static let dustRelayFee = PolicyConstants.dustRelayFee

    /// The minimum non-witness size for transactions we're willing to relay/mine: one larger than 64 .
    static let minStandardNonWitnessSize = PolicyConstants.minStandardNonWitnessTransactionSize

    /// The maximum number of sigops we're willing to relay/mine in a single transaction.
    static let maxStandardSigopsCost = PolicyConstants.maxStandardTransactionSigopsCost

    /// The maximum number of potentially executed legacy signature operations in a single standard tx.
    static let maxLegacySigops = PolicyConstants.maxTransactionLegacySigops
}

/// Consensus.
public extension Transaction.Input {

    /// Interpret sequence numbers as relative lock-time constraints.
    static let standardLocktimeVerifyOption = PolicyConstants.standardLocktimeVerifyOption
}

/// Policy.
public extension Transaction.Witness {

    /// Maximum allowed byte size of a P2WSH redeem script in the witness.
    static let maxP2WSHScriptSize = PolicyConstants.maxP2WSHScriptSize

    /// Maximum number of stack items permitted in a P2WSH witness.
    static let maxP2WSHStackItems = PolicyConstants.maxP2WSHStackItems

    /// Maximum byte size for a single stack item in a P2WSH witness.
    static let maxP2WSHStackItemSize = PolicyConstants.maxP2WSHStackItemSize

    /// Maximum byte size for a single stack item in a Tapscript witness.
    static let maxTapscriptStackItemSize = PolicyConstants.maxTapscriptStackItemSize
}

/// Policy.
public extension Script {

    /// Default for -permitbaremultisig
    static let defaultPermitBareMultisig = PolicyConstants.defaultPermitBareMultisig

    /// Default for -datacarrier
    static let defaultAcceptDatacarrier = PolicyConstants.defaultAcceptDatacarrier

    // The maximum size of a standard _ScriptSig_.
    static let maxStandardInputScriptSize = PolicyConstants.maxStandardInputScriptSize

    /// Default setting for max data carrier size in vbytes.
    static let maxOpReturnRelay = PolicyConstants.maxOpReturnRelay

    /// Maximum number of signature check operations in standard P2SH script.
    static let maxP2SHSigops = PolicyConstants.maxP2SHSigops
}
