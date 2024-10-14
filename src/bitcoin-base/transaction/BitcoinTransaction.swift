import Foundation
import BitcoinCrypto

/// A Bitcoin transaction.
///
/// A Bitcoin transaction spends a number of coins into new unspent outputs. The newly created coins become potential inputs to subsequent transactions.
///
/// Only in the case of coinbase transactions outputs can be created without spending existing coins. The combined value of such transaction comes from the block's aggregated fees and subsidy.
///
/// A lock time can also be specified for a transaction which prevents it from being processed until a given block or time has passed.
///
/// Version 2 transactions allows for relative lock times based on age of spent outputs.
public struct BitcoinTransaction: Equatable, Sendable {

    // MARK: - Initializers
    
    /// Creates a transaction from its inputs and outputs.
    /// - Parameters:
    ///   - version: Defaults fo version 1. Version 2 can be specified to unlock per input relative lock times.
    ///   - locktime: The absolute lock time by which this transaction will be able to be mined. It can be specified as a block height or a calendar date. Disabled by default.
    ///   - inputs: The coins this transaction will be spending.
    ///   - outputs: The new coins this transaction will create.
    public init(version: TransactionVersion = .v1, locktime: TransactionLocktime = .disabled, inputs: [TransactionInput], outputs: [TransactionOutput]) {
        self.version = version
        self.locktime = locktime
        self.inputs = inputs
        self.outputs = outputs
    }

    // MARK: - Instance Properties

    /// The transaction's version.
    public let version: TransactionVersion

    /// Lock time value applied to this transaction. It represents the earliest time at which this transaction should be considered valid.
    public let locktime: TransactionLocktime

    /// All of the inputs consumed (coins spent) by this transaction.
    public let inputs: [TransactionInput]

    /// The new outputs to be created by this transaction.
    public let outputs: [TransactionOutput]

    // MARK: - Computed Properties

    /// The transaction's identifier. More [here](https://learnmeabitcoin.com/technical/txid). Serialized as big-endian.
    public var identifier: Data { Data(Hash256.hash(data: identifierData).reversed()) }

    /// BIP141
    /// The transaction's witness identifier as defined in BIP141. More [here](https://river.com/learn/terms/w/wtxid/). Serialized as big-endian.
    public var witnessIdentifier: Data { Data(Hash256.hash(data: data).reversed()) }

    /// BIP141: Transaction weight is defined as Base transaction size * 3 + Total transaction size (ie. the same method as calculating Block weight from Base size and Total size).
    public var weight: Int { baseSize * 4 + witnessSize }

    ///  BIP141: Virtual transaction size is defined as Transaction weight / 4 (rounded up to the next integer).
    public var virtualSize: Int { Int((Double(weight) / 4).rounded(.up)) }

    public var isCoinbase: Bool {
        inputs.count == 1 && inputs[0].outpoint == TransactionOutpoint.coinbase
    }

    /// BIP141
    var hasWitness: Bool { inputs.contains { $0.witness != .none } }

    // MARK: - Instance Methods

    /// Creates an outpoint from a particular output in this transaction to be used when creating an ``TransactionInput`` instance.
    public func outpoint(_ outputIndex: Int) -> TransactionOutpoint {
        precondition(outputIndex < outputs.count)
        return .init(transaction: identifier, output: outputIndex)
    }

    public func withUnlockScript(_ script: BitcoinScript, input inputIndex: Int) -> Self {
        precondition(inputs.indices.contains(inputIndex))
        let oldInput = inputs[inputIndex]
        let newInput = TransactionInput(outpoint: oldInput.outpoint, sequence: oldInput.sequence, script: script, witness: oldInput.witness)
        let newInputs = inputs[..<inputIndex] + [newInput] + inputs[inputIndex.advanced(by: 1)...]
        return .init(version: version, locktime: locktime, inputs: .init(newInputs), outputs: outputs)
    }

    public func withWitness(_ witnessElements: [Data], input inputIndex: Int) -> Self {
        precondition(inputs.indices.contains(inputIndex))
        let oldInput = inputs[inputIndex]
        let newInput = TransactionInput(outpoint: oldInput.outpoint, sequence: oldInput.sequence, script: oldInput.script, witness: .init(witnessElements))
        let newInputs = inputs[..<inputIndex] + [newInput] + inputs[inputIndex.advanced(by: 1)...]
        return .init(version: version, locktime: locktime, inputs: .init(newInputs), outputs: outputs)
    }

    // MARK: - Type Properties

    /// The total amount of bitcoin supply is actually less than this number. But `maxMoney` as a limit for any amount is a  consensus-critical constant.
    static let maxMoney = 2_100_000_000_000_000

    /// Coinbase transaction outputs can only be spent after this number of new blocks (network rule).
    static let coinbaseMaturity = 100

    static let maxBlockWeight = 4_000_000
    static let identifierSize = 32

    // MARK: - Type Methods

    public static func makeGenesisTransaction(blockSubsidy: Int) -> Self {

        let genesisMessage = "The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"

        let genesisTx = BitcoinTransaction(
            version: .v1,
            inputs: [.init(
                outpoint: .coinbase,
                sequence: .final,
                script: .init([
                    .pushBytes(Data([0xff, 0xff, 0x00, 0x1d])),
                    .pushBytes(Data([0x04])),
                    .pushBytes(genesisMessage.data(using: .ascii)!)
                ]))],
            outputs: [
                .init(value: blockSubsidy,
                      script: .init([
                        .pushBytes(PublicKey.satoshi.uncompressedData!),
                        .checkSig]))
            ])

        return genesisTx
    }

    public static func makeCoinbaseTransaction(blockHeight: Int, publicKey: PublicKey, witnessMerkleRoot: Data, blockSubsidy: Int) -> Self {
        makeCoinbaseTransaction(blockHeight: blockHeight, publicKeyHash: Data(Hash160.hash(data: publicKey.data)), witnessMerkleRoot: witnessMerkleRoot, blockSubsidy: blockSubsidy)
    }

    public static func makeCoinbaseTransaction(blockHeight: Int, publicKeyHash: Data, witnessMerkleRoot: Data, blockSubsidy: Int) -> Self {
        // BIP141 Commitment Structure https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#commitment-structure
        let witnessReservedValue = Data(count: 32)

        let witnessCommitmentHeader = Data([0xaa, 0x21, 0xa9, 0xed])
        let witnessRootHash = witnessMerkleRoot
        let witnessCommitmentHash = Data(Hash256.hash(data: witnessRootHash + witnessReservedValue))

        let witnessCommitmentScript = BitcoinScript([
            .return,
            .pushBytes(witnessCommitmentHeader + witnessCommitmentHash),
        ])

        let coinbaseTx = BitcoinTransaction(version: .v2, inputs: [
            .init(outpoint: .coinbase, script: .init([.encodeMinimally(blockHeight), .zero]), witness: .init([witnessReservedValue]))
        ], outputs: [
            .init(value: blockSubsidy, script: .init([
                // Standard p2pkh
                .dup,
                .hash160,
                .pushBytes(publicKeyHash),
                .equalVerify,
                .checkSig
            ])),
            .init(value: 0, script: witnessCommitmentScript)
        ])
        return coinbaseTx
    }

    public static let dummy = Self(inputs: [.init(outpoint: .coinbase)], outputs: [])
}

extension BitcoinTransaction {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    /// BIP 144
    public init?(_ data: Data) {
        var data = data
        guard let version = TransactionVersion(data) else {
            return nil
        }
        data = data.dropFirst(TransactionVersion.size)

        // BIP144 - Check for marker and segwit flag
        let maybeSegwitMarker = data[data.startIndex]
        let maybeSegwitFlag = data[data.startIndex + 1]
        let isSegwit: Bool
        if maybeSegwitMarker == BitcoinTransaction.segwitMarker && maybeSegwitFlag == BitcoinTransaction.segwitFlag {
            isSegwit = true
            data = data.dropFirst(2)
        } else {
            isSegwit = false
        }

        guard let inputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(inputsCount.varIntSize)

        var inputs = [TransactionInput]()
        for _ in 0 ..< inputsCount {
            guard let input = TransactionInput(data) else {
                return nil
            }
            inputs.append(input)
            data = data.dropFirst(input.size)
        }

        guard let outputsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(outputsCount.varIntSize)

        var outputs = [TransactionOutput]()
        for _ in 0 ..< outputsCount {
            guard let out = TransactionOutput(data) else {
                return nil
            }
            outputs.append(out)
            data = data.dropFirst(out.size)
        }

        // BIP144
        if isSegwit {
            for i in inputs.indices {
                guard let witness = InputWitness(data) else { return nil }
                data = data.dropFirst(witness.size)
                let input = inputs[i]
                inputs[i] = .init(outpoint: input.outpoint, sequence: input.sequence, script: input.script, witness: witness)
            }
        }

        guard let locktime = TransactionLocktime(data) else {
            return nil
        }
        data = data.dropFirst(TransactionLocktime.size)
        self.init(version: version, locktime: locktime, inputs: inputs, outputs: outputs)
    }

    // MARK: - Computed Properties

    /// Raw format byte serialization of this transaction. Supports updated serialization format specified in BIP144.
    /// BIP144
    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(version.data)

        // BIP144
        if hasWitness {
            offset = ret.addData(Data([BitcoinTransaction.segwitMarker, BitcoinTransaction.segwitFlag]), at: offset)
        }
        offset = ret.addData(Data(varInt: inputsUInt64), at: offset)
        offset = ret.addData(inputs.reduce(Data()) { $0 + $1.data }, at: offset)
        offset = ret.addData(Data(varInt: outputsUInt64), at: offset)
        offset = ret.addData(outputs.reduce(Data()) { $0 + $1.data }, at: offset)

        // BIP144
        if hasWitness {
            offset = ret.addData(inputs.reduce(Data()) {
                guard let witness = $1.witness else {
                    return $0
                }
                return $0 + witness.data
            }, at: offset)
        }

        ret.addData(locktime.data, at: offset)
        return ret
    }

    /// BIP141: Total transaction size is the transaction size in bytes serialized as described in BIP144, including base data and witness data.
    public var size: Int { baseSize + witnessSize }

    private var inputsUInt64: UInt64 { .init(inputs.count) }
    private var outputsUInt64: UInt64 { .init(outputs.count) }

    var identifierData: Data {
        var ret = Data(count: baseSize)
        var offset = ret.addData(version.data)
        offset = ret.addData(Data(varInt: inputsUInt64), at: offset)
        offset = ret.addData(inputs.reduce(Data()) { $0 + $1.data }, at: offset)
        offset = ret.addData(Data(varInt: outputsUInt64), at: offset)
        offset = ret.addData(outputs.reduce(Data()) { $0 + $1.data }, at: offset)
        ret.addData(locktime.data, at: offset)
        return ret
    }

    /// BIP141: Base transaction size is the size of the transaction serialised with the witness data stripped.
    /// AKA `identifierSize`
    var baseSize: Int {
        TransactionVersion.size + inputsUInt64.varIntSize + inputs.reduce(0) { $0 + $1.size } + outputsUInt64.varIntSize + outputs.reduce(0) { $0 + $1.size } + TransactionLocktime.size
    }

    /// BIP141 / BIP144
    var witnessSize: Int {
        hasWitness ? (MemoryLayout.size(ofValue: BitcoinTransaction.segwitMarker) + MemoryLayout.size(ofValue: BitcoinTransaction.segwitFlag)) + inputs.reduce(0) { $0 + ($1.witness?.size ?? 0) } : 0
    }

    public static let identifierLength = Hash256.Digest.byteCount

    public static let coinbaseWitnessIdentifier = Data(count: identifierSize)

    /// BIP141
    private static let segwitMarker = UInt8(0x00)

    /// BIP141
    private static let segwitFlag = UInt8(0x01)

    // MARK: - Type Methods

    // No type methods yet.
}
