import Foundation
import BitcoinCrypto

/// A fully decoded Bitcoin script and its associated signature version.
///
/// If there is a portion of the data that cannot be parsed it will be stored in ``Script/unparsable``.
public struct Script: Equatable, Sendable {

    // MARK: - Initializers

    /// Creates a script from a list of operations.
    /// - Parameters:
    ///   - ops: A sequence of script operations.
    public init(_ ops: [Script.Operation]) {
        self.ops = ops
        self.unparsable = .init()
    }

    // MARK: - Instance Properties

    /// List of all decoded script operations.
    public var ops: [Script.Operation]

    /// The portion of the original script data that could not be decoded into operations.
    public var unparsable: Data

    // MARK: - Computed Properties

    /// Attempts to parse the script and return its assembly representation. Otherwise returns an empty string.
    public func asm(_ sigVersion: SigVersion = .witnessV1) -> String {
        (ops.map { $0.asm(sigVersion) } + [unparsable.hex]).joined(separator: " ")
    }

    var isEmpty: Bool {
        ops.isEmpty && unparsable.isEmpty
    }

    // BIP62
    public var isPushOnly: Bool {
        ops.allSatisfy(\.isPush) && unparsable.isEmpty
    }

    /// Whether the script is guaranteed to fail at execution, regardless of the initial stack. This allows outputs to be pruned instantly when entering the UTXO set.
    public var isUnspendable: Bool {
        let size = dataSize
        return size > 0 && ops[0] == .return || size > Script.maxScriptSize
        //(size() > 0 && *begin() == OP_RETURN) || (size() > MAX_SCRIPT_SIZE);
    }

    // BIP16
    public var isPayToScriptHash: Bool {
        if dataSize == RIPEMD160.Digest.byteCount + 3,
           ops.count == 3,
           ops[0] == .hash160,
           case .pushBytes(_) = ops[1],
           ops[2] == .equal { true } else { false }
    }

    /// BIP141
    public var isSegwit: Bool {
        if dataSize >= 3 && dataSize <= 41,
           ops.count == 2,
           case .pushBytes(_) = ops[1]
        {
            if case .constant(_) = ops[0] { true } else { ops[0] == .zero }
        } else {
            false
        }
    }

    public var witnessVersionProgram: (Int, Data)? {
        guard isSegwit else {
            return nil
        }
        return (witnessVersion, witnessProgram)
    }

    public var isPayToWitnessScriptHash: Bool {
        witnessVersion == 0 && witnessProgram.count == SHA256.Digest.byteCount
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
        guard isPushOnly else {
            throw ScriptError.nonPushOnlyScript
        }
    }

    /// Simple script execution ``ScriptRuntime``
    public func run(_ config: ScriptConfig = .standard, tx: Transaction = .dummy, input: Int = 0, prevouts: [TransactionOutput] = [], stack: [Data] = [], sigVersion: SigVersion = .base) throws -> [Data] {
        var runtime = ScriptRuntime(config, tx: tx, input: input, prevouts: prevouts)
        try runtime.run(self, stack: stack, sigVersion: sigVersion)
        return runtime.stack
    }

    // MARK: - Type Properties

    public static let empty: Self = []

    /// Maximum number of public keys per multisig.
    static let maxMultisigPubkeys = 20

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

    public static func payToPubkey(_ pubkey: PublicKey) -> Self {
        [.pushBytes(pubkey.data), .checkSig]
    }

    public static func payToPubkeyHash(_ pubkey: PublicKey) -> Self {
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

    public static func payToMultisig(_ threshold: Int, of keys: PublicKey...) -> Self {
        precondition(keys.count <= 20 && threshold >= 0 && threshold <= keys.count)
        let keyOps = keys.map { key in
            Script.Operation.pushBytes(key.data)
        }
        return .init(
            [.encodeMinimally(threshold)] +
            keyOps +
            [.encodeMinimally(keys.count), .checkMultisig]
        )
    }

    public static func payToScriptHash(_ redeem: Script) -> Self {
        payToScriptHash(Data(Hash160.hash(data: redeem.data)))
    }

    package static func payToScriptHash(_ hash: Data) -> Self {
        [.hash160, .pushBytes(hash), .equal]
    }

    public static func payToWitnessPubkeyHash(_ pubkey: PublicKey) -> Self {
        payToWitnessPubkeyHash(Data(Hash160.hash(data: pubkey.data)))
    }

    package static func payToWitnessPubkeyHash(_ hash: Data) -> Self {
        [.zero, .pushBytes(hash)]
    }

    public static func payToWitnessScriptHash(_ witness: Script) -> Self {
        let hash = Data(SHA256.hash(data: witness.data))
        return payToWitnessScriptHash(hash)
    }

    package static func payToWitnessScriptHash(_ hash: Data) -> Self {
        [.zero, .pushBytes(hash)]
    }

    public static func payToTaproot(internalKey: PublicKey, script: TapscriptTree? = nil) -> Self {
        precondition(internalKey.hasEvenY)
        let outputKey = internalKey.taprootOutputKey(script)
        return payToTaproot(outputKey)
    }

    package static func payToTaproot(_ outputKey: PublicKey) -> Self {
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

    /// BIP141 witness commitment header tag
    static let witnessCommitmentTag = Data([0xaa, 0x21, 0xa9, 0xed])

    /// BIP141 witness commitment script
    public static func witnessCommitment(witnessMerkleRoot: Data, witnessReservedValue: Data) -> Script {
        precondition(witnessReservedValue.count == 32)
        // BIP141 Commitment Structure https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#commitment-structure
        let witnessCommitmentHash = Data(Hash256.hash(data: witnessMerkleRoot + witnessReservedValue))

        return Script([
            .return,
            .pushBytes(witnessCommitmentTag + witnessCommitmentHash),
        ])
    }

    /// Is this a BIP141 witness commitment script
    public var isWitnessCommitment: Bool {
        guard ops.count == 2, ops[0] == .return, case let .pushBytes(data) = ops[1], data.count == Self.witnessCommitmentTag.count + Hash256.Digest.byteCount, data.starts(with: Self.witnessCommitmentTag) else { return false }
        return true
    }
}

extension Script {
    // BIP433 Anchor program pattern: witness v1 with 2-byte program 0x4e 0x73
    public static let anchorProgram: Data = Data([0x4e, 0x73])

    // Returns true if this script is a segwit v1 program with the anchor payload
    public var isPayToAnchor: Bool {
        guard isSegwit, witnessVersion == 1 else { return false }
        return witnessProgram == Script.anchorProgram
    }
}

extension Script {

    /// Counts the number of signature operations in this script.
    ///
    /// Analog to Bitcoin Core's `GetSigOpCount(bool fAccurate)`.
    ///
    /// - Parameter accurate: If true, count multisig ops accurately when preceded by OP_1..OP_16; otherwise assume MAX_PUBKEYS_PER_MULTISIG.
    /// - Returns: Number of signature operations.
    public func sigopCount(accurate: Bool) -> Int {
        var n = 0
        var lastOpcode: Script.Operation? = nil
        for op in ops {
            switch op {
            case .checkSig, .checkSigVerify:
                n += 1
            case .checkMultisig, .checkMultisigVerify:
                if accurate, let lastOpcode {
                    if case let .constant(v) = lastOpcode, (1...16).contains(Int(v)) {
                        n += Int(v)
                    } else {
                        n += Script.maxMultisigPubkeys
                    }
                } else {
                    n += Script.maxMultisigPubkeys
                }
            default:
                break
            }
            lastOpcode = op
        }
        return n
    }

    /// If this is not P2SH, returns sigopCount(true). Otherwise, extracts the redeemScript from scriptSig's last push and returns its sigop count.
    ///
    /// `GetSigopCount(const CScript& scriptSig)` from Bitcoin Core, adapted to Swift.
    public func sigopCount(inputScript scriptSig: Script) -> Int {
        guard isPayToScriptHash else {
            return sigopCount(accurate: true)
        }

        // This is a pay-to-script-hash scriptPubKey;
        // get the last item that the scriptSig pushes onto the stack:
        if let lastOp = scriptSig.ops.last, let lastPush = lastOp.pushedData, let subScript = try? Script(lastPush) {
            return subScript.sigopCount(accurate: true)
        }
        // TODO: Return 0? check Bitcoin Core
        fatalError()
    }
}

extension Script: ExpressibleByArrayLiteral {

    public init(arrayLiteral ops: Script.Operation...) {
        self.init(ops)
    }
}

/// Data extensions.
extension Script: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws {
        var ops = [Script.Operation]()
        while let op: Script.Operation = try? decoder.decode() {
            ops.append(op)
        }
        self.ops = ops
        unparsable = try decoder.decode()
    }

    // TODO: Replace conformance with public CustomBinaryEncodable with 2 encodings: default/nil for unprefixed and a prefixed one
    public init(prefixedFrom decoder: inout BinaryDecoder) throws {
        let size: VarInt = try decoder.decode()
        decoder.setLimit(size.value)
        try self.init(from: &decoder)
        decoder.resetLimit()
    }

    public init(prefixedData: Data) throws {
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
        encoder.encode(VarInt(dataSize))
        encode(to: &encoder)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        for op in ops {
            counter.count(op)
        }
        counter.countSize(unparsable.count)
    }

    public func encodingSizePrefixed(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(VarInt(dataSize))
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

// Binary parsing

import BinaryParsing

extension Script {
    public init(parsing input: inout ParserSpan) throws {
        let size = try VarInt(parsing: &input)

        // decoder.setLimit(size.value)
        let range = try input.sliceRange(byteCount: size.value)
        try input.seek(toRange: range)

        var ops = [Script.Operation]()
        while let op = try? Script.Operation(parsing: &input) {
            ops.append(op)
        }
        self.ops = ops
        unparsable = .init([UInt8](parsingRemainingBytes: &input))

        // decoder.resetLimit()
        try input.seek(toAbsoluteOffset: range.upperBound)
    }
}

extension Script {
    public func encode(to output: inout OutputRawSpan) throws {
        for op in ops {
            try op.encode(to: &output)
        }
        output.append(contentsOf: unparsable)
    }
}
