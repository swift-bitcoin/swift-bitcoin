import BitcoinBase

private enum PolicyConstants {

    /// See ``BitcoinBase/Transaction/witnessScaleFactor``.
    static let witnessScaleFactor = 4

    /// See ``BitcoinBase/Transaction/maxStandardWeight``.
    static let maxStandardWeight = 400_000

    /// See ``BitcoinBase/Transaction/maxDustOutputs``.
    static let maxDustOutputs = 1

    /// See ``BitcoinBase/Transaction/dustRelayFee``.
    static let dustRelayFee = 3000

    /// See ``BitcoinBase/Transaction/minStandardNonWitnessSize``.
    static let minStandardNonWitnessTransactionSize = 65

    /// See ``BitcoinBase/Script/maxStandardSize``.
    static let maxStandardSize = 1650

    /// See ``BitcoinBase/Script/maxOpReturnRelay``.
    static let maxOpReturnRelay = maxStandardWeight / witnessScaleFactor

    /// See ``BitcoinBase/Script/maxP2SHSigops``.
    static let maxP2SHSigops = 15

    /// See ``BitcoinBase/Script/maxTransactionLegacySigops``.
    static let maxTransactionLegacySigops = 2_500

    // MARK: - P2WSH limits (witness standardness)

    /// See ``BitcoinBase/Transaction/Witness/maxP2WSHScriptSize``.
    static let maxP2WSHScriptSize = 3600 // bytes

    /// See ``BitcoinBase/Transaction/Witness/maxP2WSHStackItems``.
    static let maxP2WSHStackItems = 100

    /// See ``BitcoinBase/Transaction/Witness/maxP2WSHStackItemSize``.
    static let maxP2WSHStackItemSize = 80 // bytes

    /// See ``BitcoinBase/Transaction/Witness/maxTapscriptStackItemSize``.
    static let maxTapscriptStackItemSize = 80 // bytes
}

/// Policy.
public extension Transaction {

    /// Witness scale factor.
    static let witnessScaleFactor = PolicyConstants.witnessScaleFactor

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

}

/// Policy.
public extension Script {
    // The maximum size of a standard _ScriptSig_.
    static let maxStandardSize = PolicyConstants.maxStandardSize

    /// Default setting for max data carrier size in vbytes.
    static let maxOpReturnRelay = PolicyConstants.maxOpReturnRelay

    /// Maximum number of signature check operations in standard P2SH script.
    static let maxP2SHSigops = PolicyConstants.maxP2SHSigops

    /// The maximum number of potentially executed legacy signature operations in a single standard tx.
    static let maxTransactionLegacySigops = PolicyConstants.maxTransactionLegacySigops
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
