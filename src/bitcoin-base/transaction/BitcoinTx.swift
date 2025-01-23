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
public struct BitcoinTx: Equatable, Sendable {

    // MARK: - Initializers
    
    /// Creates a transaction from its inputs and outputs.
    /// - Parameters:
    ///   - version: Defaults fo version 1. Version 2 can be specified to unlock per input relative lock times.
    ///   - locktime: The absolute lock time by which this transaction will be able to be mined. It can be specified as a block height or a calendar date. Disabled by default.
    ///   - ins: The coins this transaction will be spending.
    ///   - outs: The new coins this transaction will create.
    public init(version: TxVersion = .v1, locktime: TxLocktime = .disabled, ins: [TxIn], outs: [TxOut]) {
        self.version = version
        self.locktime = locktime
        self.ins = ins
        self.outs = outs
    }

    // MARK: - Instance Properties

    /// The transaction's version.
    public var version: TxVersion

    /// Lock time value applied to this transaction. It represents the earliest time at which this transaction should be considered valid.
    public var locktime: TxLocktime

    /// All of the inputs consumed (coins spent) by this transaction.
    public var ins: [TxIn]

    /// The new outputs to be created by this transaction.
    public var outs: [TxOut]

    // MARK: - Computed Properties

    /// The transaction's identifier. More [here](https://learnmeabitcoin.com/technical/txid). Serialized as big-endian.
    public var id: Data { Data(Hash256.hash(data: nonWitnessData).reversed()) }

    /// BIP141
    /// The transaction's witness identifier as defined in BIP141. More [here](https://river.com/learn/terms/w/wtxid/). Serialized as big-endian.
    public var witnessID: Data { Data(Hash256.hash(data: data).reversed()) }

    /// BIP141: Transaction weight is defined as Base transaction size * 3 + Total transaction size (ie. the same method as calculating Block weight from Base size and Total size).
    public var weight: Int { baseSize * 4 + witnessSize }

    ///  BIP141: Virtual transaction size is defined as Transaction weight / 4 (rounded up to the next integer).
    public var virtualSize: Int { Int((Double(weight) / 4).rounded(.up)) }

    public var isCoinbase: Bool {
        ins.count == 1 && ins[0].outpoint == TxOutpoint.coinbase
    }

    public var valueOut: SatoshiAmount {
        outs.reduce(0) { $0 + $1.value }
    }

    /// BIP141
    var hasWitness: Bool { ins.contains { $0.witness != .none } }

    // MARK: - Instance Methods

    /// Creates an outpoint from a particular output in this transaction to be used when creating an ``TxIn`` instance.
    public func outpoint(_ index: Int) -> TxOutpoint {
        precondition(index < outs.count)
        return .init(tx: id, txOut: index)
    }

    // MARK: - Type Properties

    /// The total amount of bitcoin supply is actually less than this number. But `maxMoney` as a limit for any amount is a  consensus-critical constant.
    static package let maxMoney = 2_100_000_000_000_000

    // MARK: - Type Methods

    public static func makeGenesisTx(blockSubsidy: Int) -> Self {

        let genesisMessage = "The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"

        let genesisTx = BitcoinTx(
            version: .v1,
            ins: [.init(
                outpoint: .coinbase,
                sequence: .final,
                script: .init([
                    .pushBytes(Data([0xff, 0xff, 0x00, 0x1d])),
                    .pushBytes(Data([0x04])),
                    .pushBytes(genesisMessage.data(using: .ascii)!)
                ]))],
            outs: [
                .init(value: blockSubsidy,
                      script: .init([
                        .pushBytes(PubKey.satoshi.uncompressedData!),
                        .checkSig]))
            ])

        return genesisTx
    }

    public static func makeCoinbaseTx(blockHeight: Int, pubkey: PubKey, witnessMerkleRoot: Data, blockSubsidy: Int) -> Self {
        makeCoinbaseTx(blockHeight: blockHeight, pubkeyHash: Data(Hash160.hash(data: pubkey.data)), witnessMerkleRoot: witnessMerkleRoot, blockSubsidy: blockSubsidy)
    }

    public static func makeCoinbaseTx(blockHeight: Int, pubkeyHash: Data, witnessMerkleRoot: Data, blockSubsidy: Int) -> Self {
        // BIP141 Commitment Structure https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#commitment-structure
        let witnessReservedValue = Data(count: 32)

        let witnessCommitmentHeader = Data([0xaa, 0x21, 0xa9, 0xed])
        let witnessRootHash = witnessMerkleRoot
        let witnessCommitmentHash = Data(Hash256.hash(data: witnessRootHash + witnessReservedValue))

        let witnessCommitmentScript = BitcoinScript([
            .return,
            .pushBytes(witnessCommitmentHeader + witnessCommitmentHash),
        ])

        let coinbaseTx = BitcoinTx(version: .v2, ins: [
            .init(outpoint: .coinbase, script: .init([.encodeMinimally(blockHeight), .zero]), witness: .init([witnessReservedValue]))
        ], outs: [
            .init(value: blockSubsidy, script: .init([
                // Standard p2pkh
                .dup,
                .hash160,
                .pushBytes(pubkeyHash),
                .equalVerify,
                .checkSig
            ])),
            .init(value: 0, script: witnessCommitmentScript)
        ])
        return coinbaseTx
    }

    public static let dummy = Self(ins: [.init(outpoint: .coinbase)], outs: [])
}

extension BitcoinTx {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    /// BIP 144
    public init?(_ data: Data) {
        var data = data
        guard let version = TxVersion(data) else {
            return nil
        }
        data = data.dropFirst(TxVersion.size)

        // BIP144 - Check for marker and segwit flag
        let maybeSegwitMarker = data[data.startIndex]
        let maybeSegwitFlag = data[data.startIndex + 1]
        let isSegwit: Bool
        if maybeSegwitMarker == BitcoinTx.segwitMarker && maybeSegwitFlag == BitcoinTx.segwitFlag {
            isSegwit = true
            data = data.dropFirst(2)
        } else {
            isSegwit = false
        }

        guard let insCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(insCount.varIntSize)

        var ins = [TxIn]()
        for _ in 0 ..< insCount {
            guard let txIn = try? TxIn(binaryData: data) else {
                return nil
            }
            ins.append(txIn)
            data = data.dropFirst(txIn.size)
        }

        guard let outsCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(outsCount.varIntSize)

        var outs = [TxOut]()
        for _ in 0 ..< outsCount {
            guard let out = TxOut(data) else {
                return nil
            }
            outs.append(out)
            data = data.dropFirst(out.size)
        }

        // BIP144
        if isSegwit {
            for i in ins.indices {
                guard let witness = TxWitness(data) else { return nil }
                data = data.dropFirst(witness.size)
                let txIn = ins[i]
                ins[i] = .init(outpoint: txIn.outpoint, sequence: txIn.sequence, script: txIn.script, witness: witness)
            }
        }

        guard let locktime = TxLocktime(data) else {
            return nil
        }
        data = data.dropFirst(TxLocktime.size)
        self.init(version: version, locktime: locktime, ins: ins, outs: outs)
    }

    // MARK: - Computed Properties

    /// Raw format byte serialization of this transaction. Supports updated serialization format specified in BIP144.
    /// BIP144
    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(version.data)

        // BIP144
        if hasWitness {
            offset = ret.addData(Data([BitcoinTx.segwitMarker, BitcoinTx.segwitFlag]), at: offset)
        }
        offset = ret.addData(Data(varInt: insUInt64), at: offset)
        offset = ret.addData(ins.reduce(Data()) { $0 + $1.binaryData }, at: offset)
        offset = ret.addData(Data(varInt: outsUInt64), at: offset)
        offset = ret.addData(outs.reduce(Data()) { $0 + $1.data }, at: offset)

        // BIP144
        if hasWitness {
            offset = ret.addData(ins.reduce(Data()) {
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

    private var insUInt64: UInt64 { .init(ins.count) }
    private var outsUInt64: UInt64 { .init(outs.count) }

    private var nonWitnessData: Data {
        var ret = Data(count: baseSize)
        var offset = ret.addData(version.data)
        offset = ret.addData(Data(varInt: insUInt64), at: offset)
        offset = ret.addData(ins.reduce(Data()) { $0 + $1.binaryData }, at: offset)
        offset = ret.addData(Data(varInt: outsUInt64), at: offset)
        offset = ret.addData(outs.reduce(Data()) { $0 + $1.data }, at: offset)
        ret.addData(locktime.data, at: offset)
        return ret
    }

    /// BIP141: Base transaction size is the size of the transaction serialised with the witness data stripped.
    /// AKA `identifierSize`
    var baseSize: Int {
        TxVersion.size + insUInt64.varIntSize + ins.reduce(0) { $0 + $1.size } + outsUInt64.varIntSize + outs.reduce(0) { $0 + $1.size } + TxLocktime.size
    }

    /// BIP141 / BIP144
    var witnessSize: Int {
        hasWitness ? (MemoryLayout.size(ofValue: BitcoinTx.segwitMarker) + MemoryLayout.size(ofValue: BitcoinTx.segwitFlag)) + ins.reduce(0) { $0 + ($1.witness?.size ?? 0) } : 0
    }

    public static let idLength = Hash256.Digest.byteCount

    public static let coinbaseWitnessID = Data(count: idLength)

    /// BIP141
    private static let segwitMarker = UInt8(0x00)

    /// BIP141
    private static let segwitFlag = UInt8(0x01)

    // MARK: - Type Methods

    // No type methods yet.
}
