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
    public var id: Data { Data(Hash256.hash(data: dataNonWitness).reversed()) }

    /// BIP141
    /// The transaction's witness identifier as defined in BIP141. More [here](https://river.com/learn/terms/w/wtxid/). Serialized as big-endian.
    public var witnessID: Data { Data(Hash256.hash(data: binaryData).reversed()) }

    /// BIP141: Transaction weight is defined as Base transaction size * 3 + Total transaction size (ie. the same method as calculating Block weight from Base size and Total size).
    public var weight: Int { sizeNonWitness * 4 + witnessSize }

    ///  BIP141: Virtual transaction size is defined as Transaction weight / 4 (rounded up to the next integer).
    public var virtualSize: Int { Int((Double(weight) / 4).rounded(.up)) }

    public var isCoinbase: Bool {
        ins.count == 1 && ins[0].outpoint == TxOutpoint.coinbase
    }

    public var valueOut: SatoshiAmount {
        outs.reduce(0) { $0 + $1.value }
    }

    /// BIP141
    var hasWitness: Bool { ins.contains { $0.witness != [] } }

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

    // MARK: - Computed Properties

    /// BIP141 / BIP144
    var witnessSize: Int {
        hasWitness ? BitcoinTx.segwitMarkerAndFlag.count + ins.reduce(0) { $0 + $1.witness.binarySize } : 0
    }

    public static let idLength = Hash256.Digest.byteCount

    public static let coinbaseWitnessID = Data(count: idLength)

    /// BIP141
    private static let segwitMarkerAndFlag = Data([0, 1])

    // MARK: - Type Methods

    // No type methods yet.
}

extension BitcoinTx: BinaryCodable {

    public init(from decoder: inout BitcoinCrypto.BinaryDecoder) throws(BitcoinCrypto.BinaryDecodingError) {
        version = try decoder.decode()

        // BIP144 - Check for marker and segwit flag
        let isSegwit: Bool
        if decoder.peek(2) == BitcoinTx.segwitMarkerAndFlag {
            try decoder.decode(2)
            isSegwit = true
        } else {
            isSegwit = false
        }

        ins = try decoder.decode()
        outs = try decoder.decode()

        // BIP144
        if isSegwit {
            for i in ins.indices {
                ins[i].witness = try decoder.decode()
            }
        }

        locktime = try decoder.decode()
    }
    
    public func encode(to encoder: inout BitcoinCrypto.BinaryEncoder) {
        encoder.encode(version)
        // BIP144
        if hasWitness {
            encoder.encode(BitcoinTx.segwitMarkerAndFlag)
        }
        encoder.encode(ins)
        encoder.encode(outs)
        // BIP144
        if hasWitness {
            for witness in ins.map(\.witness) {
                encoder.encode(witness)
            }
        }
        encoder.encode(locktime)
    }
    
    public func encodeNonWitness(to encoder: inout BitcoinCrypto.BinaryEncoder) {
        encoder.encode(version)
        encoder.encode(ins)
        encoder.encode(outs)
        encoder.encode(locktime)
    }
    
    public func encodingSize(_ counter: inout BitcoinCrypto.BinaryEncodingSizeCounter) {
        counter.count(version)
        // BIP144
        if hasWitness {
            counter.count(BitcoinTx.segwitMarkerAndFlag)
        }
        counter.count(ins)
        counter.count(outs)
        // BIP144
        if hasWitness {
            for witness in ins.compactMap({ $0.witness }) {
                counter.count(witness)
            }
        }
        counter.count(locktime)
    }

    public func encodingSizeNonWitness(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(version)
        counter.count(ins)
        counter.count(outs)
        counter.count(locktime)
    }

    /// Data used for the transaction identifier ``BitcoinTx/id``.
    public var dataNonWitness: Data {
        var encoder = BinaryEncoder(size: sizeNonWitness)
        encodeNonWitness(to: &encoder)
        return encoder.data
    }

    /// BIP141: Base transaction size is the size of the transaction serialised with the witness data stripped.
    /// AKA `identifierSize`
    public var sizeNonWitness: Int {
        var counter = BinaryEncodingSizeCounter()
        self.encodingSizeNonWitness(&counter)
        return counter.size
    }
}
