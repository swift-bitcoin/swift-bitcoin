import Foundation

/// A bitcoin transaction.
public struct Transaction: Equatable {

    // MARK: - Initializers

    public init(version: Version, locktime: Locktime, inputs: [Input], outputs: [Output]) {
        self.version = version
        self.locktime = locktime
        self.inputs = inputs
        self.outputs = outputs
    }

    /// BIP 144
    public init?(_ data: Data) {
        var data = data
        guard let version = Version(data) else {
            return nil
        }
        data = data.dropFirst(Version.size)

        // BIP144 - Check for marker and segwit flag
        let maybeSegwitMarker = data[data.startIndex]
        let maybeSegwitFlag = data[data.startIndex + 1]
        let isSegwit: Bool
        if maybeSegwitMarker == Transaction.segwitMarker && maybeSegwitFlag == Transaction.segwitFlag {
            isSegwit = true
            data = data.dropFirst(2)
        } else {
            isSegwit = false
        }

        guard let inputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(inputsCount.varIntSize)

        var inputs = [Input]()
        for _ in 0 ..< inputsCount {
            guard let input = Input(data) else {
                return nil
            }
            inputs.append(input)
            data = data.dropFirst(input.size)
        }

        guard let outputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(outputsCount.varIntSize)

        var outputs = [Output]()
        for _ in 0 ..< outputsCount {
            guard let out = Output(data) else {
                return nil
            }
            outputs.append(out)
            data = data.dropFirst(out.size)
        }

        // BIP144
        if isSegwit {
            for i in inputs.indices {
                guard let witness = Witness(data) else {
                    return nil
                }
                inputs[i].witness = witness
                data = data.dropFirst(witness.size)
            }
        }

        guard let locktime = Locktime(data) else {
            return nil
        }
        data = data.dropFirst(Locktime.size)
        self.init(version: version, locktime: locktime, inputs: inputs, outputs: outputs)
    }

    // MARK: - Instance Properties

    /// The transaction's version.
    public let version: Version

    /// Lock time value applied to this transaction. It represents the earliest time at which this transaction should be considered valid.
    public var locktime: Locktime

    /// All of the inputs consumed by this transaction.
    public var inputs: [Input]

    /// The outputs created by this transaction.
    public var outputs: [Output]

    /// BIP144 - Raw format byte serialization of this transaction. Supports updated serialization format specified in BIP144.
    public var data: Data {
        var ret = Data()
        ret += version.data

        // BIP144
        if hasWitness {
            ret += Data([Transaction.segwitMarker, Transaction.segwitFlag])
        }
        ret += Data(varInt: inputsUInt64)
        ret += inputs.reduce(Data()) { $0 + $1.data }
        ret += Data(varInt: outputsUInt64)
        ret += outputs.reduce(Data()) { $0 + $1.data }

        // BIP144
        if hasWitness {
            ret += inputs.reduce(Data()) {
                guard let witness = $1.witness else {
                    return $0
                }
                return $0 + witness.data
            }
        }

        ret += locktime.data
        return ret
    }

    var identifierData: Data {
        var ret = Data()
        ret += version.data
        ret += Data(varInt: inputsUInt64)
        ret += inputs.reduce(Data()) { $0 + $1.data }
        ret += Data(varInt: outputsUInt64)
        ret += outputs.reduce(Data()) { $0 + $1.data }
        ret += locktime.data
        return ret
    }

    /// The transaction's identifier. More [here](https://learnmeabitcoin.com/technical/txid). Serialized as big-endian.
    public var identifier: Data { Data(hash256(identifierData).reversed()) }

    /// BIP141
    /// The transaction's witness identifier as defined in BIP141. More [here](https://river.com/learn/terms/w/wtxid/). Serialized as big-endian.
    public var witnessIdentifier: Data { Data(hash256(data).reversed()) }

    /// BIP141: Transaction weight is defined as Base transaction size * 3 + Total transaction size (ie. the same method as calculating Block weight from Base size and Total size).
    public var weight: Int { baseSize * 4 + witnessSize }

    /// BIP141: Total transaction size is the transaction size in bytes serialized as described in BIP144, including base data and witness data.
    public var size: Int { baseSize + witnessSize }

    ///  BIP141: Virtual transaction size is defined as Transaction weight / 4 (rounded up to the next integer).
    public var virtualSize: Int { Int((Double(weight) / 4).rounded(.up)) }

    public var isCoinbase: Bool {
        inputs.count == 1 && inputs[0].outpoint == Outpoint.coinbase
    }

    private var inputsUInt64: UInt64 { .init(inputs.count) }
    private var outputsUInt64: UInt64 { .init(outputs.count) }

    /// BIP141: Base transaction size is the size of the transaction serialised with the witness data stripped.
    private var baseSize: Int {
        Version.size + inputsUInt64.varIntSize + inputs.reduce(0) { $0 + $1.size } + outputsUInt64.varIntSize + outputs.reduce(0) { $0 + $1.size } + Locktime.size
    }

    /// BIP141 / BIP144
    private var witnessSize: Int {
        hasWitness ? (MemoryLayout.size(ofValue: Transaction.segwitMarker) + MemoryLayout.size(ofValue: Transaction.segwitFlag)) + inputs.reduce(0) { $0 + ($1.witness?.size ?? 0) } : 0
    }

    /// BIP141
    private var hasWitness: Bool { inputs.contains { $0.witness != .none } }

    private var valueOut: Amount {
        outputs.reduce(0) { $0 + $1.value }
    }

    // MARK: - Instance Methods

    public func verify(previousOutputs: [Output], configuration: ScriptConfigurarion = .standard) -> Bool {
        for i in inputs.indices {
            do {
                try verify(inputIndex: i, previousOutputs: previousOutputs, configuration: configuration)
            } catch {
                print("\(error) \(error.localizedDescription)")
                return false
            }
        }
        return true
    }

    /// Initial simplified version of transaction verification that allows for script execution.
    func verify(inputIndex: Int, previousOutputs: [Output], configuration: ScriptConfigurarion) throws {

        precondition(previousOutputs.count == inputs.count)

        let scriptSig = inputs[inputIndex].script
        let scriptPubKey = previousOutputs[inputIndex].script

        // BIP16
        let isPayToScriptHash = configuration.payToScriptHash && scriptPubKey.isPayToScriptHash

        // BIP141
        let isNativeSegwit = configuration.witness && scriptPubKey.isSegwit
        let isSegwit: Bool
        let witnessVersion: Int?
        let witnessProgram: Data?

        // The scriptSig must be exactly empty or validation fails.
        if isNativeSegwit && !scriptSig.isEmpty {
            throw ScriptError.scriptSigNotEmpty
        }

        // BIP62, BIP16
        if configuration.pushOnly || isPayToScriptHash {
            try scriptSig.checkPushOnly()
        }

        if isNativeSegwit {
            isSegwit = true
            witnessVersion = scriptPubKey.witnessVersion
            witnessProgram = scriptPubKey.witnessProgram
        } else {
            // Execute scriptSig
            var stack = [Data]()
            try scriptSig.run(&stack, transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, configuration: configuration)
            let stackTmp = stack // BIP16

            // Execute scriptPubKey separately on the stack left by scriptSig
            try scriptPubKey.run(&stack, transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, configuration: configuration)
            if let last = stack.last, !ScriptBoolean(last).value {
                throw ScriptError.falseReturned
            }

            // BIP16
            if isPayToScriptHash {
                stack = stackTmp
                guard let data = stack.popLast() else { preconditionFailure() }

                let redeemScript = SerializedScript(data)

                // BIP141 - P2SH witness program
                if redeemScript.isSegwit {
                    isSegwit = true
                    witnessVersion = redeemScript.witnessVersion
                    witnessProgram = redeemScript.witnessProgram

                    // The scriptSig must be exactly a push of the BIP16 redeemScript or validation fails.
                    if !stack.isEmpty {
                        // We already checked that scriptSig was push only.
                        throw ScriptError.scriptSigTooManyPushes
                    }
                } else {
                    isSegwit = false
                    witnessVersion = .none
                    witnessProgram = .none

                    try redeemScript.run(&stack, transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, configuration: configuration)
                    if let last = stack.last, !ScriptBoolean(last).value {
                        throw ScriptError.falseReturned
                    }
                }

            } else {
                isSegwit = false
                witnessVersion = .none
                witnessProgram = .none
            }

            if !isSegwit && configuration.cleanStack && stack.count != 1 { // BIP62, BIP16
                throw ScriptError.uncleanStack
            }
        }

        if isSegwit {
            guard let witnessVersion, let witnessProgram else { preconditionFailure() }
            try verifyWitness(inputIndex: inputIndex, witnessVersion: witnessVersion, witnessProgram: witnessProgram, previousOutputs: previousOutputs, configuration: configuration)
        }
    }

    private func verifyWitness(inputIndex: Int, witnessVersion: Int, witnessProgram: Data, previousOutputs: [Output], configuration: ScriptConfigurarion) throws {
        guard witnessVersion == 0 else {
            if configuration.discourageUpgradableWitnessProgram {
                throw ScriptError.disallowedWitnessVersion
            }
            // If the version byte is 1 to 16, no further interpretation of the witness program or witness stack happens
            return
        }

        guard var stack = inputs[inputIndex].witness?.elements else { preconditionFailure() }

        if witnessProgram.count == 20 {
            // If the version byte is 0, and the witness program is 20 bytes: It is interpreted as a pay-to-witness-public-key-hash (P2WPKH) program.

            // The witness must consist of exactly 2 items (≤ 520 bytes each). The first one a signature, and the second one a public key.
            guard stack.count == 2, stack.allSatisfy({ $0.count <= 520 }) else {
                throw ScriptError.witnessElementTooBig
            }

            // For P2WPKH witness program, the scriptCode is 0x1976a914{20-byte-pubkey-hash}88ac.
            let witnessScript = ParsedScript([
                .dup, .hash160, .pushBytes(witnessProgram), .equalVerify, .checkSig
            ], version: .witnessV0)

            try witnessScript.run(&stack, transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, configuration: configuration)

            // The verification must result in a single TRUE on the stack.
            guard stack.count == 1, let last = stack.last, ScriptBoolean(last).value else {
                throw ScriptError.falseReturned
            }
        } else if witnessProgram.count == 32 {
            // If the version byte is 0, and the witness program is 32 bytes: It is interpreted as a pay-to-witness-script-hash (P2WSH) program.

            // The witnessScript (≤ 10,000 bytes) is popped off the initial witness stack.
            guard var stack = inputs[inputIndex].witness?.elements, let witnessScriptRaw = stack.popLast() else {
                preconditionFailure()
            }
            if witnessScriptRaw.count > 10_000 {
                throw ScriptError.witnessScriptTooBig
            }

            // SHA256 of the witnessScript must match the 32-byte witness program.
            guard sha256(witnessScriptRaw) == witnessProgram else {
                throw ScriptError.wrongWitnessScriptHash
            }

            // The witnessScript is deserialized, and executed after normal script evaluation with the remaining witness stack (≤ 520 bytes for each stack item).
            guard stack.allSatisfy({ $0.count <= 520 }) else {
                throw ScriptError.witnessElementTooBig
            }
            let witnessScript = SerializedScript(witnessScriptRaw, version: .witnessV0)
            try witnessScript.run(&stack, transaction: self, inputIndex: inputIndex, previousOutputs: previousOutputs, configuration: configuration)

            // The script must not fail, and result in exactly a single TRUE on the stack.
            guard stack.count == 1, let last = stack.last, ScriptBoolean(last).value else {
                throw ScriptError.falseReturned
            }
        } else {
            // If the version byte is 0, but the witness program is neither 20 nor 32 bytes, the script must fail.
            throw ScriptError.witnessProgramWrongLength
        }
    }

    /// Creates an outpoint from a particular output in this transaction to be used when creating an ``Input`` instance.
    public func outpoint(for output: Int) -> Outpoint? {
        guard output < outputs.count else {
            return .none
        }
        return .init(transaction: identifier, output: output)
    }

    /// This function is called when validating a transaction and it's consensus critical.
    func check() throws {
        // Basic checks that don't depend on any context
        guard !inputs.isEmpty else {
            throw TransactionError.noInputs
        }
        guard !outputs.isEmpty else {
            throw TransactionError.noOutputs
        }

        // Size limits (this doesn't take the witness into account, as that hasn't been checked for malleability)
        guard weight <= Self.maxBlockWeight else {
            throw TransactionError.oversized
        }

        // Check for negative or overflow output values (see CVE-2010-5139)
        var valueOut: Amount = 0
        for output in outputs {
            guard output.value >= 0 else {
                throw TransactionError.negativeOutput
            }
            guard output.value <= Self.maxMoney else {
                throw TransactionError.outputTooLarge
            }
            valueOut += output.value
            guard valueOut >= 0 && valueOut <= Self.maxMoney else {
                throw TransactionError.totalOutputsTooLarge
            }
        }

        // Check for duplicate inputs (see CVE-2018-17144)
        // While Consensus::CheckTxInputs does check if all inputs of a tx are available, and UpdateCoins marks all inputs
        // of a tx as spent, it does not check if the tx has duplicate inputs.
        // Failure to run this check will result in either a crash or an inflation bug, depending on the implementation of
        // the underlying coins database.
        var outpoints = Set<Outpoint>()
        for input in inputs {
            outpoints.insert(input.outpoint)
        }
        guard inputs.count == outpoints.count else {
            throw TransactionError.duplicateInput
        }

        if isCoinbase && (inputs[0].script.size < 2 || inputs[0].script.size > 100) {
            throw TransactionError.coinbaseLengthOutOfRange
        }
        if !isCoinbase {
            for input in inputs {
                if input.outpoint == Outpoint.coinbase {
                    throw TransactionError.missingOutpoint
                }
            }
        }
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``Transaction.check()``.
    func checkInputs(coins: [Outpoint : Coin], spendHeight: Int) throws {
        // are the actual inputs available?
        if !isCoinbase {
            for outpoint in inputs.map(\.outpoint) {
                guard coins[outpoint] != .none else {
                    throw TransactionError.inputMissingOrSpent
                }
            }
        }

        var valueIn = Amount(0)
        for input in inputs {
            let outpoint = input.outpoint
            guard let coin = coins[outpoint] else {
                preconditionFailure()
            }
            if coin.isCoinbase && spendHeight - coin.height < Self.coinbaseMaturity {
                throw TransactionError.prematureCoinbaseSpend
            }
            valueIn += coin.output.value
            guard coin.output.value >= 0 && coin.output.value <= Self.maxMoney,
                  valueIn >= 0 && valueIn <= Self.maxMoney
            else {
                throw TransactionError.inputValuesOutOfRange
            }
        }

        // This is guaranteed by calling Transaction.check() before this function.
        precondition(valueOut >= 0 && valueOut <= Self.maxMoney)

        guard valueIn >= valueOut else {
            throw TransactionError.inputsValueBelowOutput
        }

        let fee = valueIn - valueOut
        guard fee >= 0 && fee <= Self.maxMoney else {
            throw TransactionError.feeOutOfRange
        }
    }

    func isFinal(blockHeight: Int?, blockTime: Int?) -> Bool {
        precondition((blockHeight == .none && blockTime != .none) || (blockHeight != .none && blockTime == .none))
        if locktime == .disabled { return true }

        if let blockHeight, let txBlockHeight = locktime.blockHeight, txBlockHeight < blockHeight {
            return true
        } else if let blockTime, let txBlockTime = locktime.secondsSince1970, txBlockTime < blockTime {
            return true
        }

        // Even if tx.nLockTime isn't satisfied by nBlockHeight/nBlockTime, a
        // transaction is still considered final if all inputs' nSequence ==
        // SEQUENCE_FINAL (0xffffffff), in which case nLockTime is ignored.
        //
        // Because of this behavior OP_CHECKLOCKTIMEVERIFY/CheckLockTime() will
        // also check that the spending input's nSequence != SEQUENCE_FINAL,
        // ensuring that an unsatisfied nLockTime value will actually cause
        // IsFinalTx() to return false here:
        return inputs.allSatisfy { $0.sequence == .final }
    }

    /// BIP68 - Untested - Entrypoint 1.
    func checkSequenceLocks(scriptConfiguration: ScriptConfigurarion, coins: [Outpoint : Coin], chainTip: Int, previousBlockMedianTimePast: Int) throws {
        // CheckSequenceLocks() uses chainActive.Height()+1 to evaluate
        // height based locks because when SequenceLocks() is called within
        // ConnectBlock(), the height of the block *being*
        // evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the
        // *next* block, we need to use one more than chainActive.Height()
        let nextBlockHeight = chainTip + 1
        var heights = [Int]()
        // pcoinsTip contains the UTXO set for chainActive.Tip()
        for input in inputs {
            guard let coin = coins[input.outpoint] else {
                preconditionFailure()
            }
            if coin.height == 0x7FFFFFFF /* MEMPOOL_HEIGHT */ {
                // Assume all mempool transaction confirm in the next block
                heights.append(nextBlockHeight)
            } else {
                heights.append(coin.height)
            }
        }
        let lockPair = calculateSequenceLocks(scriptConfiguration: scriptConfiguration, previousHeights: &heights, blockHeight: nextBlockHeight)
        try evaluateSequenceLocks(blockHeight: nextBlockHeight, previousBlockMedianTimePast: previousBlockMedianTimePast, lockPair: lockPair)
    }

    /// BIP68 - Untested. Entrypoint 2.
    func sequenceLocks(scriptConfiguration: ScriptConfigurarion, previousHeights: inout [Int], blockHeight: Int, previousBlockMedianTimePast: Int) throws {
        try evaluateSequenceLocks(blockHeight: blockHeight, previousBlockMedianTimePast: previousBlockMedianTimePast, lockPair: calculateSequenceLocks(scriptConfiguration: scriptConfiguration, previousHeights: &previousHeights, blockHeight: blockHeight))
    }

    /// BIP68 - Untested
    /// Calculates the block height and previous block's median time past at
    /// which the transaction will be considered final in the context of BIP 68.
    /// Also removes from the vector of input heights any entries which did not
    /// correspond to sequence locked inputs as they do not affect the calculation.
    /// Called from ``Transaction.sequenceLocks()``.
    func calculateSequenceLocks(scriptConfiguration: ScriptConfigurarion, previousHeights: inout [Int], blockHeight: Int) -> (Int, Int) {

        precondition(previousHeights.count == inputs.count);

        // Will be set to the equivalent height- and time-based nLockTime
        // values that would be necessary to satisfy all relative lock-
        // time constraints given our view of block chain history.
        // The semantics of nLockTime are the last invalid height/time, so
        // use -1 to have the effect of any height or time being valid.
        var minHeight = -1;
        var minTime = -1;

        // tx.nVersion is signed integer so requires cast to unsigned otherwise
        // we would be doing a signed comparison and half the range of nVersion
        // wouldn't support BIP68.
        let enforceBIP68 = version >= .v2 && scriptConfiguration.lockTimeSequence

        // Do not enforce sequence numbers as a relative lock time
        // unless we have been instructed to
        guard enforceBIP68 else { return (minHeight, minTime) }

        for inputIndex in inputs.indices {
            let input = inputs[inputIndex]

            // Sequence numbers with the most significant bit set are not
            // treated as relative lock-times, nor are they given any
            // consensus-enforced meaning at this point.
            if input.sequence.isLocktimeDisabled {
                // The height of this input is not relevant for sequence locks
                previousHeights[inputIndex] = 0
                continue
            }

            let coinHeight = previousHeights[inputIndex]

            if let locktimeSeconds = input.sequence.locktimeSeconds {
                // NOTE: Subtract 1 to maintain nLockTime semantics
                // BIP68 relative lock times have the semantics of calculating
                // the first block or time at which the transaction would be
                // valid. When calculating the effective block time or height
                // for the entire transaction, we switch to using the
                // semantics of nLockTime which is the last invalid block
                // time or height.  Thus we subtract 1 from the calculated
                // time or height.
                //
                // Time-based relative lock-times are measured from the
                // smallest allowed timestamp of the block containing the
                // txout being spent, which is the median time past of the
                // block prior.
                let coinTime = 0 // TODO: Retrieve the block previous to the coin height `blockHeight.GetAncestor(std::max(nCoinHeight-1, 0))->GetMedianTimePast()`
                minTime = max(minTime, coinTime + locktimeSeconds - 1)
            } else if let locktimeBlocks = input.sequence.locktimeBlocks {
                minHeight = max(minHeight, coinHeight + locktimeBlocks - 1)
            }
        }
        return (minHeight, minTime)
    }

    /// BIP68 - Untested. Called by ``Transaction.checkSequenceLocks()`` and ``Transaction.sequenceLocks()``.
    func evaluateSequenceLocks(blockHeight: Int, previousBlockMedianTimePast: Int, lockPair: (Int, Int)) throws {
        if lockPair.0 >= blockHeight || lockPair.1 >= previousBlockMedianTimePast {
            throw TransactionError.futureLockTime
        }
    }

    func verifySignature(extendedSignature: Data, publicKey: Data, inputIndex: Int, previousOutput: Output, scriptCode: Data, scriptVersion: ScriptVersion) -> Bool {
        if extendedSignature.isEmpty {
            return false
        }
        let signature = extendedSignature.dropLast()
        let sighashTypeData = extendedSignature.dropFirst(extendedSignature.count - 1)
        guard let sighashType = SighashType(sighashTypeData) else {
            preconditionFailure()
        }
        let sighash = if scriptVersion == .legacy {
            signatureHash(sighashType: sighashType, inputIndex: inputIndex, previousOutput: previousOutput, scriptCode: scriptCode)
        } else if scriptVersion == .witnessV0 {
            segwitSignatureHash(sighashType: sighashType, inputIndex: inputIndex, previousOutput: previousOutput, scriptCode: scriptCode)
        } else { preconditionFailure() }
        let result = verifyECDSA(sig: signature, msg: sighash, publicKey: publicKey)
        return result
    }

    /// Signature hash for legacy inputs.
    /// - Parameters:
    ///   - sighashType: Signature hash type.
    ///   - inputIndex: Transaction input index.
    ///   - previousOutput: Previous unspent transaction output corresponding to the transaction input being signed/verified.
    ///   - scriptCode: The executed script. For Pay-to-Script-Hash outputs it should correspond to the redeem script.
    /// - Returns: A hash value for use while either signing or verifying a transaction input.
    func signatureHash(sighashType: SighashType, inputIndex: Int, previousOutput: Output, scriptCode: Data) -> Data {
        if sighashType.isSingle && inputIndex >= outputs.count {
            // Note: The transaction that uses SIGHASH_SINGLE type of signature should not have more inputs than outputs. However if it does (because of the pre-existing implementation), it shall not be rejected, but instead for every "illegal" input (meaning: an input that has an index bigger than the maximum output index) the node should still verify it, though assuming the hash of 0000000000000000000000000000000000000000000000000000000000000001
            //
            // From [https://en.bitcoin.it/wiki/BIP_0143]:
            // In the original algorithm, a uint256 of 0x0000......0001 is committed if the input index for a SINGLE signature is greater than or equal to the number of outputs.
            return Data([0x01]) + Data(repeating: 0, count: 31)
        }
        let sigMsg = signatureMessage(sighashType: sighashType, inputIndex: inputIndex, scriptCode: scriptCode)
        return hash256(sigMsg)
    }

    /// Aka sigMsg. See https://en.bitcoin.it/wiki/OP_CHECKSIG
    func signatureMessage(sighashType: SighashType, inputIndex: Int, scriptCode: Data) -> Data {
        var newIns = [Input]()
        if sighashType.isAnyCanPay {
            // Procedure for Hashtype SIGHASH_ANYONECANPAY
            // The txCopy input vector is resized to a length of one.
            // The current transaction input (with scriptPubKey modified to subScript) is set as the first and only member of this vector.
            newIns.append(.init(outpoint: inputs[inputIndex].outpoint, sequence: inputs[inputIndex].sequence, script: .init(scriptCode)))
        } else {
            inputs.enumerated().forEach { i, input in
                newIns.append(.init(
                    outpoint: input.outpoint,
                    // SIGHASH_NONE | SIGHASH_SINGLE - All other txCopy inputs aside from the current input are set to have an nSequence index of zero.
                    sequence: i == inputIndex || (!sighashType.isNone && !sighashType.isSingle) ? input.sequence : .initial,
                    // The scripts for all transaction inputs in txCopy are set to empty scripts (exactly 1 byte 0x00)
                    // The script for the current transaction input in txCopy is set to subScript (lead in by its length as a var-integer encoded!)
                    script: i == inputIndex ? .init(scriptCode) : .empty
                ))
            }
        }
        var newOuts: [Output]
        // Procedure for Hashtype SIGHASH_SINGLE

        if sighashType.isSingle {
            // The output of txCopy is resized to the size of the current input index+1.
            // All other txCopy outputs aside from the output that is the same as the current input index are set to a blank script and a value of (long) -1.
            newOuts = []

            outputs.enumerated().forEach { i, out in
                guard i <= inputIndex else {
                    return
                }
                if i == inputIndex {
                    newOuts.append(out)
                } else if i < inputIndex {
                    // Value is "long -1" which means UInt64(bitPattern: -1) aka UInt64.max
                    newOuts.append(.init(value: -1, script: SerializedScript.empty))
                }
            }
        } else if sighashType.isNone {
            newOuts = []
        } else {
            newOuts = outputs
        }
        let txCopy = Transaction(
            version: version,
            locktime: locktime,
            inputs: newIns,
            outputs: newOuts
        )
        return txCopy.data + sighashType.data32
    }

    /// BIP143
    func segwitSignatureHash(sighashType: SighashType, inputIndex: Int, previousOutput: Output, scriptCode: Data) -> Data {
        hash256(segwitSignatureMessage(sighashType: sighashType, inputIndex: inputIndex, scriptCode: scriptCode, amount: previousOutput.value))
    }

    /// BIP143: SegWit v0 signature message (sigMsg).
    func segwitSignatureMessage(sighashType: SighashType, inputIndex: Int, scriptCode: Data, amount: Amount) -> Data {
        //If the ANYONECANPAY flag is not set, hashPrevouts is the double SHA256 of the serialization of all input outpoints;
        // Otherwise, hashPrevouts is a uint256 of 0x0000......0000.
        var hashPrevouts: Data
        if sighashType.isAnyCanPay {
            hashPrevouts = Data(repeating: 0, count: 32)
        } else {
            let prevouts = inputs.reduce(Data()) { $0 + $1.outpoint.data }
            hashPrevouts = hash256(prevouts)
        }
        
        // If none of the ANYONECANPAY, SINGLE, NONE sighash type is set, hashSequence is the double SHA256 of the serialization of nSequence of all inputs;
        // Otherwise, hashSequence is a uint256 of 0x0000......0000.
        let hashSequence: Data
        if !sighashType.isAnyCanPay && !sighashType.isSingle && !sighashType.isNone {
            let sequence = inputs.reduce(Data()) {
                $0 + $1.sequence.data
            }
            hashSequence = hash256(sequence)
        } else {
            hashSequence = Data(repeating: 0, count: 32)
        }

        // If the sighash type is neither SINGLE nor NONE, hashOutputs is the double SHA256 of the serialization of all output amount (8-byte little endian) with scriptPubKey (serialized as scripts inside CTxOuts);
        // If sighash type is SINGLE and the input index is smaller than the number of outputs, hashOutputs is the double SHA256 of the output amount with scriptPubKey of the same index as the input;
        // Otherwise, hashOutputs is a uint256 of 0x0000......0000.[7]
        let hashOuts: Data
        if !sighashType.isSingle && !sighashType.isNone {
            let outsData = outputs.reduce(Data()) { $0 + $1.data }
            hashOuts = hash256(outsData)
        } else if sighashType.isSingle && inputIndex < outputs.count {
            hashOuts = hash256(outputs[inputIndex].data)
        } else {
            hashOuts = Data(repeating: 0, count: 32)
        }

        let outpointData = inputs[inputIndex].outpoint.data
        let scriptCodeData = scriptCode.varLenData
        let amountData = withUnsafeBytes(of: amount) { Data($0) }
        let sequenceData = inputs[inputIndex].sequence.data

        let remaindingData = sequenceData + hashOuts + locktime.data + sighashType.data32
        return version.data + hashPrevouts + hashSequence + outpointData + scriptCodeData + amountData + remaindingData
    }

    // MARK: - Type Properties

    /// The total amount of bitcoin supply is actually less than this number. But `maxMoney` as a limit for any amount is a  consensus-critical constant.
    static let maxMoney = 2_100_000_000_000_000

    /// Coinbase transaction outputs can only be spent after this number of new blocks (network rule).
    static let coinbaseMaturity = 100

    static let maxBlockWeight = 4_000_000
    static let identifierSize = 32

    /// BIP141
    private static let segwitMarker = UInt8(0x00)

    /// BIP141
    private static let segwitFlag = UInt8(0x01)

    // MARK: - Type Methods

    // No type methods yet.
}
