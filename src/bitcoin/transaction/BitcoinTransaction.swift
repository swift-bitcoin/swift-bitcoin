import Foundation
import BitcoinCrypto

/// A bitcoin transaction.
public struct BitcoinTransaction: Equatable {

    // MARK: - Initializers

    public init(version: TransactionVersion, locktime: TransactionLocktime = .disabled, inputs: [TransationInput], outputs: [TransactionOutput]) {
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

    /// All of the inputs consumed by this transaction.
    public let inputs: [TransationInput]

    /// The outputs created by this transaction.
    public let outputs: [TransactionOutput]

    // MARK: - Computed Properties

    /// The transaction's identifier. More [here](https://learnmeabitcoin.com/technical/txid). Serialized as big-endian.
    public var identifier: Data { Data(hash256(identifierData).reversed()) }

    /// BIP141
    /// The transaction's witness identifier as defined in BIP141. More [here](https://river.com/learn/terms/w/wtxid/). Serialized as big-endian.
    public var witnessIdentifier: Data { Data(hash256(data).reversed()) }

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

    /// Creates an outpoint from a particular output in this transaction to be used when creating an ``Input`` instance.
    public func outpoint(for output: Int) -> TransactionOutpoint? {
        guard output < outputs.count else {
            return .none
        }
        return .init(transaction: identifier, output: output)
    }

    // MARK: - Type Properties

    /// The total amount of bitcoin supply is actually less than this number. But `maxMoney` as a limit for any amount is a  consensus-critical constant.
    static let maxMoney = 2_100_000_000_000_000

    /// Coinbase transaction outputs can only be spent after this number of new blocks (network rule).
    static let coinbaseMaturity = 100

    static let maxBlockWeight = 4_000_000
    static let identifierSize = 32

    // MARK: - Type Methods

    // No type methods yet.
}
