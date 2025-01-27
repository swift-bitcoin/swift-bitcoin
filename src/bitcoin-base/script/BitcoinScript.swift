import Foundation
import BitcoinCrypto

/// A fully decoded Bitcoin script and its associated signature version.
///
/// If there is a portion of the data that cannot be parsed it will be stored in ``BitcoinScript/unparsable``.
public struct BitcoinScript: Equatable, Sendable {

    // MARK: - Initializers
    
    /// Creates a script from a list of operations.
    /// - Parameters:
    ///   - ops: A sequence of script operations.
    public init(_ ops: [ScriptOp]) {
        self.ops = ops
        self.unparsable = .init()
    }

    // MARK: - Instance Properties

    /// List of all decoded script operations.
    public let ops: [ScriptOp]

    /// The portion of the original script data that could not be decoded into operations.
    public let unparsable: Data

    // MARK: - Computed Properties

    /// Attempts to parse the script and return its assembly representation. Otherwise returns an empty string.
    public func asm(_ sigVersion: SigVersion = .witnessV1) -> String {
        (ops.map { $0.asm(sigVersion) } + [unparsable.hex]).joined(separator: " ")
    }

    var isEmpty: Bool {
        ops.isEmpty && unparsable.isEmpty
    }

    // BIP16
    public var isPayToScriptHash: Bool {
        if binarySize == RIPEMD160.Digest.byteCount + 3,
           ops.count == 3,
           ops[0] == .hash160,
           case .pushBytes(_) = ops[1],
           ops[2] == .equal { true } else { false }
    }

    /// BIP141
    var isSegwit: Bool {
        if binarySize >= 3 && binarySize <= 41,
           ops.count == 2,
           case .pushBytes(_) = ops[1]
        {
            if case .constant(_) = ops[0] { true } else { ops[0] == .zero }
        } else {
            false
        }
    }

    /// BIP141
    var witnessProgram: Data {
        precondition(isSegwit)
        guard case let .pushBytes(data) = ops[1] else {
            preconditionFailure()
        }
        return data
    }

    /// BIP141
    var witnessVersion: Int {
        precondition(isSegwit)
        return if case let .constant(value) = ops[0] { Int(value) } else if ops[0] == .zero { 0 } else { preconditionFailure() }
    }

    // MARK: - Instance Methods

    // BIP62
    func checkPushOnly() throws {
        guard ops.allSatisfy(\.isPush), unparsable.isEmpty else {
            throw ScriptError.nonPushOnlyScript
        }
    }

    /// Simple script execution ``ScriptContext``
    public func run(_ config: ScriptConfig = .standard, tx: BitcoinTx = .dummy, txIn: Int = 0, prevouts: [TxOut] = [], stack: [Data] = [], sigVersion: SigVersion = .base) throws -> [Data] {
        var context = ScriptContext(config, tx: tx, txIn: txIn, prevouts: prevouts)
        try context.run(self, stack: stack, sigVersion: sigVersion)
        return context.stack
    }

    // MARK: - Type Properties

    public static let empty: Self = []

    /// Maximum number of public keys per multisig.
    static let maxMultiSigPubkeys = 20

    /// Maximum number of non-push operations per script.
    static let maxOps = 201

    /// Maximum script length in bytes.
    static let maxScriptSize = 10_000

    /// BIP342
    static let maxStackElementSize = 520
    static let sigopBudgetBase = 50
    static let sigopBudgetDecrement = 50

    /// BIP342
    static let maxStackElements = 1_000

    // MARK: - Type Methods

    public static func payToPubkey(_ pubkey: PubKey) -> Self {
        [.pushBytes(pubkey.data), .checkSig]
    }

    public static func payToPubkeyHash(_ pubkey: PubKey) -> Self {
        payToPubkeyHash(Data(Hash160.hash(data: pubkey.data)))
    }

    package static func payToPubkeyHash(_ hash: Data) -> Self {
        [.dup, .hash160, .pushBytes(hash), .equalVerify, .checkSig]
    }

    /// This is the script code for signing Pay-to-Witness-Public-Key-Hash inputs. It contains the same operations as a Pay-to-Public-Key-Hash output script but the signature version is bumped to Witness V0.
    public static func segwitPKHScriptCode(_ hash: Data) -> Self {
        precondition(hash.count == Hash160.Digest.byteCount)
        return [.dup, .hash160, .pushBytes(hash), .equalVerify, .checkSig]
    }

    public static func payToMultiSignature(_ threshold: Int, of keys: PubKey...) -> Self {
        precondition(keys.count <= 20 && threshold >= 0 && threshold <= keys.count)
        let keyOps = keys.map { key in
            ScriptOp.pushBytes(key.data)
        }
        return .init(
            [.encodeMinimally(threshold)] +
            keyOps +
            [.encodeMinimally(keys.count), .checkMultiSig]
        )
    }

    public static func payToScriptHash(_ redeem: BitcoinScript) -> Self {
        payToScriptHash(Data(Hash160.hash(data: redeem.binaryData)))
    }

    package static func payToScriptHash(_ hash: Data) -> Self {
        [.hash160, .pushBytes(hash), .equal]
    }

    public static func payToWitnessPubkeyHash(_ pubkey: PubKey) -> Self {
        payToWitnessPubkeyHash(Data(Hash160.hash(data: pubkey.data)))
    }

    package static func payToWitnessPubkeyHash(_ hash: Data) -> Self {
        [.zero, .pushBytes(hash)]
    }

    public static func payToWitnessScriptHash(_ witness: BitcoinScript) -> Self {
        let hash = Data(SHA256.hash(data: witness.binaryData))
        return payToWitnessScriptHash(hash)
    }

    package static func payToWitnessScriptHash(_ hash: Data) -> Self {
        [.zero, .pushBytes(hash)]
    }

    public static func payToTaproot(internalKey: PubKey, script: ScriptTree? = .none) -> Self {
        precondition(internalKey.hasEvenY)
        let outputKey = internalKey.taprootOutputKey(script)
        return payToTaproot(outputKey)
    }

    package static func payToTaproot(_ outputKey: PubKey) -> Self {
        [.constant(1), .pushBytes(outputKey.xOnlyData)]
    }

    public static func dataCarrier(_ message: String) -> Self {
        let messageData = message.data(using: .utf8)!
        precondition(messageData.count <= UInt32.max)
        return [
            .return,
            .encodeMinimally(messageData)
        ]
    }
}

extension BitcoinScript: ExpressibleByArrayLiteral {

    public init<D: DataProtocol>(_ data: D) {
        // TODO: Can script decoding really never fail? Even with unparsable data being taken into consideration…
        try! self.init(binaryData: data)
    }

    public init(arrayLiteral ops: ScriptOp...) {
        self.init(ops)
    }
}

/// Data extensions.
extension BitcoinScript: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        var ops = [ScriptOp]()
        while let op: ScriptOp = try? decoder.decode() {
            ops.append(op)
        }
        self.ops = ops
        unparsable = try decoder.decode()
    }

    public init(prefixedFrom decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let size: VarInt = try decoder.decode()
        decoder.setLimit(size.value)
        try self.init(from: &decoder)
        decoder.resetLimit()
    }

    init(prefixedData: Data) throws(BinaryDecodingError) {
        var decoder = BinaryDecoder(prefixedData)
        try self.init(prefixedFrom: &decoder)
    }

    public func encode(to encoder: inout BinaryEncoder) {
        for op in ops {
            encoder.encode(op)
        }
        encoder.encode(unparsable)
    }

    public func encodePrefixed(to encoder: inout BinaryEncoder) {
        encoder.encode(VarInt(binarySize))
        encode(to: &encoder)
    }
    
    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        for op in ops {
            counter.count(op)
        }
        counter.countSize(unparsable.count)
    }

    public func encodingSizePrefixed(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(VarInt(binarySize))
        encodingSize(&counter)
    }

    public var dataPrefixed: Data {
        var encoder = BinaryEncoder(size: sizePrefixed)
        encodePrefixed(to: &encoder)
        return encoder.data
    }

    public var sizePrefixed: Int {
        var counter = BinaryEncodingSizeCounter()
        self.encodingSizePrefixed(&counter)
        return counter.size
    }
}
