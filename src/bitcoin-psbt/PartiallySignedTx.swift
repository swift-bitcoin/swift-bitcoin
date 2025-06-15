import Foundation
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet

public enum PartiallySignedTxState: Equatable, Sendable {
    case created, complete
}

typealias KeyedValues = [PSBTMap.Key : Data]

/// A Partially Signed Bitcoin Transaction (PSBT).
///
/// The Partially Signed Bitcoin Transaction (PSBT) format consists of key-value maps. Each map consists of a sequence of key-value records, terminated by a `0x00` byte.
///
///     <psbt> := <magic> <global-map> <input-map>* <output-map>*
///     <magic> := 0x70 0x73 0x62 0x74 0xFF
///     <global-map> := <keypair>* 0x00
///     <input-map> := <keypair>* 0x00
///     <output-map> := <keypair>* 0x00
///     <keypair> := <key> <value>
///     <key> := <keylen> <keytype> <keydata>
///     <value> := <valuelen> <valuedata>
///
/// Where:
///
/// `<keytype>` - A compact size unsigned integer representing the type. This compact size unsigned integer must be minimally encoded, i.e. if the value can be represented using one byte, it must be represented as one byte. There can be multiple entries with the same `<keytype>` within a specific `<map>`, but the `<key>` must be unique.
/// `<keylen>` - The compact size unsigned integer containing the combined length of `<keytype>` and `<keydata>`
/// `<valuelen>` - The compact size unsigned integer containing the length of `<valuedata>`.
/// `<magic>` - Magic bytes which are ASCII for psbt [2] followed by a separator of `0xff`. This integer must be serialized in most significant byte order.
///
public struct PartiallySignedTx: Equatable, Sendable, CustomBinaryCodable {

    public struct In: Equatable, Sendable, CustomBinaryCodable {

        public init(
            prevoutTx: Transaction? = nil,
            witnessPrevout: TransactionOutput? = nil,
            partialSigs: [PublicKey : ExtendedSig] = [:],
            sighashType: SighashType? = nil,
            redeemScript: Script? = nil,
            witnessScript: Script? = nil,
            derivationPaths: [PublicKey : DerivationPath] = [:],
            finalScriptSig: Script? = nil,
            finalScriptWitness: Transaction.Witness? = nil,
            ripemd160Preimages: Set<Data> = [],
            sha256Preimages: Set<Data> = [],
            hash160Preimages: Set<Data> = [],
            hash256Preimages: Set<Data> = [],
            proprietaryInfo: ProprietaryInfo = [:]
        ) {
            self.prevoutTx = prevoutTx
            self.witnessPrevout = witnessPrevout
            self.partialSigs = partialSigs
            self.sighashType = sighashType
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
            self.derivationPaths = derivationPaths
            self.finalScriptSig = finalScriptSig
            self.finalScriptWitness = finalScriptWitness
            self.ripemd160Preimages = ripemd160Preimages
            self.sha256Preimages = sha256Preimages
            self.hash160Preimages = hash160Preimages
            self.hash256Preimages = hash256Preimages
            self.proprietaryInfo = proprietaryInfo
            additionalTypes = [:]
        }

        public init(from decoder: inout BinaryDecoder, encoding: Never?) throws(PartiallySignedTxError) {
            let map: PSBTMap
            do {
                map = try decoder.decode()
            } catch PSBTMapError.duplicateKey {
                throw .duplicateKey
            } catch {
                throw .missingOutputMaps
            }
            try self.init(from: map)
        }

        init(from map: PSBTMap) throws(PartiallySignedTxError) {
            var prevoutTx = Transaction?.none
            var witnessPrevout = TransactionOutput?.none

            var partialSigs = [PublicKey : ExtendedSig]()
            var sighashType = SighashType?.none

            var redeemScript = Script?.none
            var witnessScript = Script?.none

            var derivationPaths = [PublicKey: DerivationPath]()

            var finalScriptSig = Script?.none
            var finalScriptWitness = Transaction.Witness?.none

            var ripemd160Preimages = Set<Data>()
            var sha256Preimages = Set<Data>()
            var hash160Preimages = Set<Data>()
            var hash256Preimages = Set<Data>()

            var proprietaryInfo: ProprietaryInfo = [:]
            var additionalTypes: KeyedValues = [:]

            for (k, v) in map.entries {
                switch k.type {
                case PSBTInputKeyType.nonWitnessUTXO.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Non-witness UTXO")
                    }
                    guard let tx = try? Transaction(binaryData: v) else {
                        throw .invalidInputPreviousTransaction
                    }
                    prevoutTx = tx
                case PSBTInputKeyType.witnessUTXO.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Witness UTXO")
                    }
                    guard let out = try? TransactionOutput(binaryData: v) else {
                        throw .invalidInputPreviousOutput
                    }
                    witnessPrevout = out
                case PSBTInputKeyType.partialSig.rawValue:
                    guard let pubkey = PublicKey(k.data) else {
                        throw .invalidPublicKey
                    }
                    guard let sig = ExtendedSig(v) else {
                        throw .invalidSignature
                    }
                    partialSigs[pubkey] = sig
                case PSBTInputKeyType.sighashType.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Sighath type")
                    }
                    guard v.count == 4, let s = try? SighashType(binaryData: v, encoding: .fullLength) else {
                        throw .invalidInputSighashType
                    }
                    sighashType = s
                case PSBTInputKeyType.redeemScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Redeem script")
                    }
                    guard let script = try? Script(binaryData: v) else {
                        throw .invalidInputRedeemScript
                    }
                    redeemScript = script
                case PSBTInputKeyType.witnessScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Witness script")
                    }
                    guard let script = try? Script(binaryData: v) else {
                        throw .invalidInputWitnessScript
                    }
                    witnessScript = script
                case PSBTInputKeyType.derivationPath.rawValue:
                    guard let pubkey = PublicKey(k.data) else {
                        throw .invalidPublicKey
                    }
                    guard let path = try? DerivationPath(binaryData: v) else {
                        throw .invalidPublicKeyDerivation
                    }
                    derivationPaths[pubkey] = path
                case PSBTInputKeyType.finalScriptSig.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Final scriptSig")
                    }
                    guard let script = try? Script(binaryData: v) else {
                        throw .invalidInputFinalScriptSig
                    }
                    finalScriptSig = script
                case PSBTInputKeyType.finalScriptWitness.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Final script witness")
                    }
                    guard let script = try? Transaction.Witness(binaryData: v) else {
                        throw .invalidInputFinalScriptWitness
                    }
                    finalScriptWitness = script
                case PSBTInputKeyType.ripemd160Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(RIPEMD160.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    ripemd160Preimages.insert(preimage)
                case PSBTInputKeyType.sha256Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(SHA256.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    sha256Preimages.insert(preimage)
                case PSBTInputKeyType.hash160Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(Hash160.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    hash160Preimages.insert(preimage)
                case PSBTInputKeyType.hash256Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(Hash256.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    hash256Preimages.insert(preimage)
                case PSBTInputKeyType.proprietary.rawValue:
                    guard let key = try? ProprietarySuperKey(binaryData: k.data) else { throw .invalidProprietaryKey }
                    if proprietaryInfo[key.id] == nil { proprietaryInfo[key.id] = [:] }
                    proprietaryInfo[key.id]![.init(key.subkey)] = v
                default:
                    additionalTypes[k] = v
                }
            }

            self.prevoutTx = prevoutTx
            self.witnessPrevout = witnessPrevout
            self.partialSigs = partialSigs
            self.sighashType = sighashType
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
            self.derivationPaths = derivationPaths
            self.finalScriptSig = finalScriptSig
            self.finalScriptWitness = finalScriptWitness
            self.ripemd160Preimages = ripemd160Preimages
            self.sha256Preimages = sha256Preimages
            self.hash160Preimages = hash160Preimages
            self.hash256Preimages = hash256Preimages
            self.proprietaryInfo = proprietaryInfo
            self.additionalTypes = additionalTypes
        }

        public internal(set) var prevoutTx: Transaction?
        public internal(set) var witnessPrevout: TransactionOutput?
        public internal(set) var partialSigs: [PublicKey : ExtendedSig]
        public internal(set) var sighashType: SighashType?
        public internal(set) var redeemScript: Script?
        public internal(set) var witnessScript: Script?
        public internal(set) var derivationPaths: [PublicKey: DerivationPath]
        public internal(set) var finalScriptSig: Script?
        public internal(set) var finalScriptWitness: Transaction.Witness?
        public internal(set) var ripemd160Preimages: Set<Data>
        public internal(set) var sha256Preimages: Set<Data>
        public internal(set) var hash160Preimages: Set<Data>
        public internal(set) var hash256Preimages: Set<Data>
        public internal(set) var proprietaryInfo: ProprietaryInfo

        private var additionalTypes: KeyedValues

        public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
            counter.count(map)
        }

        public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
            encoder.encode(map)
        }

        mutating func combine(with other: PartiallySignedTx.In) {
            if witnessPrevout == nil, let newValue = other.witnessPrevout {
                witnessPrevout = newValue
            }
            partialSigs.merge(other.partialSigs) { (current, _) in current }
            if sighashType == nil, let newValue = other.sighashType {
                sighashType = newValue
            }
            if redeemScript == nil, let newValue = other.redeemScript {
                redeemScript = newValue
            }
            if witnessScript == nil, let newValue = other.witnessScript {
                witnessScript = newValue
            }
            derivationPaths.merge(other.derivationPaths) { (current, _) in current }
            if finalScriptSig == nil, let newValue = other.finalScriptSig {
                finalScriptSig = newValue
            }
            if finalScriptWitness == nil, let newValue = other.finalScriptWitness {
                finalScriptWitness = newValue
            }
            for newValue in other.ripemd160Preimages {
                ripemd160Preimages.insert(newValue)
            }
            for newValue in other.sha256Preimages {
                sha256Preimages.insert(newValue)
            }
            for newValue in other.hash160Preimages {
                hash160Preimages.insert(newValue)
            }
            for newValue in other.hash256Preimages {
                hash256Preimages.insert(newValue)
            }
            proprietaryInfo.merge(other.proprietaryInfo) { (current, _) in current }
            additionalTypes.merge(other.additionalTypes) { (current, _) in current }
        }

        var map: PSBTMap {
            var entries: KeyedValues = [:]
            if let prevoutTx {
                entries[.init(PSBTInputKeyType.nonWitnessUTXO)] = prevoutTx.binaryData
            }
            if let witnessPrevout {
                entries[.init(PSBTInputKeyType.witnessUTXO)] = witnessPrevout.binaryData
            }
            for (k, s) in partialSigs {
                entries[.init(PSBTInputKeyType.partialSig, data: k.data)] = s.data
            }
            if let sighashType {
                entries[.init(PSBTInputKeyType.sighashType)] = sighashType.binaryData(encoding: .fullLength)
            }
            if let redeemScript {
                entries[.init(PSBTInputKeyType.redeemScript)] = redeemScript.binaryData
            }
            if let witnessScript {
                entries[.init(PSBTInputKeyType.witnessScript)] = witnessScript.binaryData
            }
            for (k, p) in derivationPaths {
                entries[.init(PSBTInputKeyType.derivationPath, data: k.data)] = p.binaryData
            }
            if let finalScriptSig {
                entries[.init(PSBTInputKeyType.finalScriptSig)] = finalScriptSig.binaryData
            }
            if let finalScriptWitness {
                entries[.init(PSBTInputKeyType.finalScriptWitness)] = finalScriptWitness.binaryData
            }
            for preimage in ripemd160Preimages {
                entries[.init(PSBTInputKeyType.ripemd160Preimage, data: Data(RIPEMD160.hash(data: preimage)))] = preimage
            }
            for preimage in sha256Preimages {
                entries[.init(PSBTInputKeyType.sha256Preimage, data: Data(SHA256.hash(data: preimage)))] = preimage
            }
            for preimage in hash160Preimages {
                entries[.init(PSBTInputKeyType.hash160Preimage, data: Data(Hash160.hash(data: preimage)))] = preimage
            }
            for preimage in hash256Preimages {
                entries[.init(PSBTInputKeyType.hash256Preimage, data: Data(Hash256.hash(data: preimage)))] = preimage
            }
            var proprietaryTypes: KeyedValues = [:]
            for (id, subkey) in proprietaryInfo {
                for (k, v) in subkey {
                    let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                    proprietaryTypes[.init(PSBTInputKeyType.proprietary, data: keyData)] = v
                }
            }
            entries.merge(proprietaryTypes) { lhs, _ in lhs }
            entries.merge(additionalTypes) { lhs, _ in lhs }
            return .init(entries: entries)
        }
    }

    public struct Out: Equatable, Sendable, CustomBinaryCodable {

        public init(
            redeemScript: Script? = nil,
            witnessScript: Script? = nil,
            derivationPaths: [PublicKey : DerivationPath] = [:],
            proprietaryInfo: ProprietaryInfo = [:]
        ) {
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
            self.derivationPaths = derivationPaths
            self.proprietaryInfo = proprietaryInfo
            additionalTypes = [:]
        }

        public init(from decoder: inout BinaryDecoder, encoding: Never?) throws(PartiallySignedTxError) {
            let map: PSBTMap
            do {
                map = try decoder.decode()
            } catch PSBTMapError.duplicateKey {
                throw .duplicateKey
            } catch {
                throw .missingOutputMaps
            }
            try self.init(from: map)
        }

        init(from map: PSBTMap) throws(PartiallySignedTxError) {
            var redeemScript = Script?.none
            var witnessScript = Script?.none

            var derivationPaths = [PublicKey : DerivationPath]()

            var proprietaryInfo: ProprietaryInfo = [:]
            var additionalTypes: KeyedValues = [:]
            for (k, v) in map.entries {
                switch k.type {
                case PSBTOutputKeyType.redeemScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyOutputKeyData("Redeem script")
                    }
                    guard let script = try? Script(binaryData: v) else {
                        throw .invalidOutputRedeemScript
                    }
                    redeemScript = script
                case PSBTOutputKeyType.witnessScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyOutputKeyData("Witness script")
                    }
                    guard let script = try? Script(binaryData: v) else {
                        throw .invalidOutputWitnessScript
                    }
                    witnessScript = script
                case PSBTOutputKeyType.derivationPath.rawValue:
                    guard let pubkey = PublicKey(k.data) else {
                        throw .invalidPublicKey
                    }
                    guard let path = try? DerivationPath(binaryData: v) else {
                        throw .invalidPublicKeyDerivation
                    }
                    derivationPaths[pubkey] = path
                case PSBTOutputKeyType.proprietary.rawValue:
                    guard let key = try? ProprietarySuperKey(binaryData: k.data) else { throw .invalidProprietaryKey }
                    if proprietaryInfo[key.id] == nil { proprietaryInfo[key.id] = [:] }
                    proprietaryInfo[key.id]![.init(key.subkey)] = v
                default:
                    additionalTypes[k] = v
                }
            }
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
            self.derivationPaths = derivationPaths
            self.proprietaryInfo = proprietaryInfo
            self.additionalTypes = additionalTypes
        }

        public internal(set) var redeemScript: Script?
        public internal(set) var witnessScript: Script?
        public internal(set) var derivationPaths: [PublicKey : DerivationPath]
        public internal(set) var proprietaryInfo: ProprietaryInfo

        private var additionalTypes: KeyedValues

        public var isEmpty: Bool {
            redeemScript == nil && witnessScript == nil && derivationPaths.isEmpty && proprietaryInfo.isEmpty && additionalTypes.isEmpty
        }

        var map: PSBTMap {
            var entries: KeyedValues = [:]
            if let redeemScript {
                entries[.init(PSBTOutputKeyType.redeemScript)] = redeemScript.binaryData
            }
            if let witnessScript {
                entries[.init(PSBTOutputKeyType.witnessScript)] = witnessScript.binaryData
            }
            for (k, p) in derivationPaths {
                entries[.init(PSBTOutputKeyType.derivationPath, data: k.data)] = p.binaryData
            }
            var proprietaryTypes = KeyedValues()
            for (id, subkey) in proprietaryInfo {
                for (k, v) in subkey {
                    let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                    proprietaryTypes[.init(PSBTOutputKeyType.proprietary, data: keyData)] = v
                }
            }
            entries.merge(proprietaryTypes) { lhs, _ in lhs }
            entries.merge(additionalTypes) { lhs, _ in lhs }
            return .init(entries: entries)
        }

        public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
            counter.count(map)
        }

        public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
            encoder.encode(map)
        }

        mutating func combine(with other: PartiallySignedTx.Out) {
            if redeemScript == nil, let newValue = other.redeemScript {
                redeemScript = newValue
            }
            if witnessScript == nil, let newValue = other.witnessScript {
                witnessScript = newValue
            }
            derivationPaths.merge(other.derivationPaths) { (current, _) in current }
            proprietaryInfo.merge(other.proprietaryInfo) { (current, _) in current }
            additionalTypes.merge(other.additionalTypes) { (current, _) in current }
        }
    }

    public init(_ tx: Transaction, xpubDerivations: [ExtendedKey : DerivationPath] = [:], proprietaryInfo: ProprietaryInfo = [:], ins: [In]? = nil, outs: [Out]? = nil) throws(PartiallySignedTxError) {
        try self.init(tx, xpubDerivations: xpubDerivations, proprietaryInfo: proprietaryInfo, ins: ins, outs: outs, additionalTypes: [:])
    }

    private init(_ tx: Transaction, xpubDerivations: [ExtendedKey : DerivationPath], proprietaryInfo: ProprietaryInfo, ins: [In]? = nil, outs: [Out]? = nil, additionalTypes: KeyedValues) throws(PartiallySignedTxError) {
        let ins = if let ins { ins } else { [In](repeating: In(), count: tx.ins.count) }
        let outs = if let outs { outs } else { [Out](repeating: Out(), count: tx.outs.count) }
        // TODO: Maybe extract signatures from signed transaction?
        precondition(tx.ins.allSatisfy { $0.witness.elements.isEmpty })
        precondition(tx.ins.allSatisfy { $0.script == .empty })
        precondition(ins.count == tx.ins.count)
        precondition(outs.count == tx.outs.count)
        unsignedTx = tx
        self.xpubDerivations = xpubDerivations
        self.proprietaryInfo = proprietaryInfo
        self.ins = ins
        self.outs = outs
        self.additionalTypes = additionalTypes
        for i in unsignedTx.ins.indices {
            let input = unsignedTx.ins[i]
            if let prevoutTx = ins[i].prevoutTx {
                guard input.outpoint.txID == prevoutTx.id else {
                    throw .transactionIDMismatch
                }
            }
        }
    }

    public init(from decoder: inout BinaryDecoder, encoding: Never?) throws(PartiallySignedTxError) {
        // Prefix (magic)
        let magic: Data
        do {
            magic = try decoder.decode(Self.magic.count)
        } catch {
            throw .invalidPrefix // Not enought bytes to decode the prefix
        }
        guard magic == Self.magic else {
            throw .invalidPrefix
        }

        // Global types
        let globalMap: PSBTMap
        do {
            globalMap = try decoder.decode()
        } catch PSBTMapError.duplicateKey {
            throw .duplicateKey
        } catch {
            throw .invalidOrMissingGlobalMap
        }

        var tx = Transaction?.none
        var version = Version?.none
        var xpubDerivations = [ExtendedKey : DerivationPath]()
        var proprietaryInfo: ProprietaryInfo = [:]
        var additionalTypes: KeyedValues = [:]
        for (k, v) in globalMap.entries {
            switch k.type {
            case PSBTGlobalKeyType.unsignedTx.rawValue:
                guard k.data.isEmpty else {
                    throw .invalidUnsignedTransactionKey
                }
                do {
                    tx = try Transaction(binaryData: v, encoding: .nonWitness)
                } catch {
                    throw .invalidUnsignedTransaction
                }
            case PSBTGlobalKeyType.xpub.rawValue:
                guard let xpub = try? ExtendedKey(binaryData: k.data), !xpub.hasSecretKey else {
                    throw .invalidExtendedPublicKey
                }
                guard v.count == (xpub.depth + 1) * MemoryLayout<UInt32>.size, let path = try? DerivationPath(binaryData: v) else {
                    throw .invalidPublicKeyDerivation
                }
                xpubDerivations[xpub] = path
            case PSBTGlobalKeyType.version.rawValue:
                guard k.data.isEmpty else {
                    throw .invalidUnsignedVersionKey
                }
                do {
                    version = try Version(binaryData: v)
                } catch {
                    throw .invalidVersionEncoding
                }
            case PSBTGlobalKeyType.proprietary.rawValue:
                guard let key = try? ProprietarySuperKey(binaryData: k.data) else { throw .invalidProprietaryKey }
                if proprietaryInfo[key.id] == nil { proprietaryInfo[key.id] = [:] }
                proprietaryInfo[key.id]![.init(key.subkey)] = v
            default:
                additionalTypes[k] = v
            }
        }

        /// Unsigned Transaction.
        guard let tx else {
            throw .missingUnsignedTransaction
        }
        guard tx.ins.allSatisfy({ $0.script == .empty }) else {
            throw .unlockScriptNonEmpty
        }
        guard tx.ins.allSatisfy({ $0.witness.elements.isEmpty }) else {
            throw .witnessNonEmpty
        }

        // PSBT Version Number
        // Version will be required in V2: `guard let versionValue = globalMap.values[Version.key] else { throw .missingVersion }`
        if let version {
            guard version == .v0 else {
                throw .invalidVersion // Only v0 supported for now
            }
        }

        var ins: [In] = []
        for _ in tx.ins {
            ins.append(try In(from: &decoder, encoding: nil))
        }

        var outs: [Out] = []
        for _ in tx.outs {
            outs.append(try Out(from: &decoder, encoding: nil))
        }
        try self.init(tx, xpubDerivations: xpubDerivations, proprietaryInfo: proprietaryInfo, ins: ins, outs: outs, additionalTypes: additionalTypes)
    }

    public let version = Version.v0
    public let unsignedTx: Transaction
    public internal(set) var xpubDerivations: [ExtendedKey : DerivationPath]
    public internal(set) var proprietaryInfo: ProprietaryInfo
    public internal(set) var ins: [In]
    public internal(set) var outs: [Out]

    var additionalTypes: KeyedValues

    public var state: PartiallySignedTxState {
        .created
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
        counter.count(Self.magic)
        counter.count(globalMap)
        for input in ins {
            counter.count(input)
        }
        for out in outs {
            counter.count(out)
        }
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
        encoder.encode(Self.magic)
        encoder.encode(globalMap)
        for input in ins {
            encoder.encode(input)
        }
        for out in outs {
            encoder.encode(out)
        }
    }

    public mutating func update(input i: Int, _ tx: Transaction) {
        ins[i].prevoutTx = tx
    }

    public mutating func update(input i: Int, _ out: TransactionOutput) {
        ins[i].witnessPrevout = out
    }

    public mutating func update(input i: Int, redeemScript: Script) {
        ins[i].redeemScript = redeemScript
    }

    public mutating func update(input i: Int, witnessScript: Script) {
        ins[i].witnessScript = witnessScript
    }

    public mutating func update(input i: Int, _ key: PublicKey, _ path: DerivationPath) {
        ins[i].derivationPaths[key] = path
    }

    public mutating func update(input i: Int, _ sighashType: SighashType) {
        ins[i].sighashType = sighashType
    }

    public func checkForSigning() throws(PartiallySignedTxError) {
        for (input, psbtIn) in zip(unsignedTx.ins, ins) {
            if let witnessPrevout = psbtIn.witnessPrevout {
                let isPayToWitnessScriptHash: Bool
                let witnessProgram: Script
                // Signer checks
                if witnessPrevout.script.isPayToScriptHash {
                    guard let redeemScript = psbtIn.redeemScript else {
                        throw .missingInputRedeemScript
                    }
                    guard redeemScript.isSegwit else {
                        throw .nonSegwitPreviousOutput
                    }
                    witnessProgram = redeemScript
                    isPayToWitnessScriptHash = redeemScript.isPayToWitnessScriptHash
                    // Check the redeem script is not the correct one for P2SH
                    guard case let .pushBytes(hash) = witnessPrevout.script.ops[1] else {
                        preconditionFailure()
                    }
                    let hash2 = Data(Hash160.hash(data: redeemScript.binaryData))
                    guard hash == hash2 else {
                        throw .wrongRedeemScript
                    }
                } else {
                    guard witnessPrevout.script.isSegwit else {
                        throw .nonSegwitPreviousOutput
                    }
                    witnessProgram = witnessPrevout.script
                    isPayToWitnessScriptHash = witnessPrevout.script.isPayToWitnessScriptHash
                }
                if isPayToWitnessScriptHash {
                    guard let witnessScript = psbtIn.witnessScript else {
                        throw .missingWitnessRedeemScript
                    }
                    guard case let .pushBytes(hashWitness) = witnessProgram.ops[1] else {
                        preconditionFailure()
                    }
                    let hashWitness2 = Data(SHA256.hash(data: witnessScript.binaryData))
                    guard hashWitness == hashWitness2 else {
                        throw .wrongWitnessScript
                    }
                }
                // If there's a prevout transaction, the outpoint must match the witness previous output
                if let prevoutTx = psbtIn.prevoutTx {
                    let prevout = prevoutTx.outs[input.outpoint.out]
                    guard prevout == witnessPrevout else {
                        throw .invalidInputPreviousOutput
                    }
                }
            } else {
                // A witness previous output was _not_ provided.
                guard let prevoutTx = psbtIn.prevoutTx else {
                    throw .missingPreviousOutput
                }
                let prevout = prevoutTx.outs[input.outpoint.out]
                guard !prevout.script.isSegwit else {
                    throw .missingWitnessPreviousOutput
                }
                if prevout.script.isPayToScriptHash {
                    guard let redeemScript = psbtIn.redeemScript else {
                        throw .missingInputRedeemScript
                    }
                    guard !redeemScript.isSegwit else {
                        throw .missingWitnessPreviousOutput
                    }
                    // Check the redeem script is not the correct one for P2SH
                    guard case let .pushBytes(hash) = prevout.script.ops[1] else {
                        preconditionFailure()
                    }
                    let hash2 = Data(Hash160.hash(data: redeemScript.binaryData))
                    guard hash == hash2 else {
                        throw .wrongRedeemScript
                    }
                }
            }
        }
    }

    public mutating func sign(input i: Int, using secretKey: SecretKey) throws(PartiallySignedTxError) {

        // Signer checks for all inputs
        try checkForSigning()

        guard let sighashType = ins[i].sighashType else {
            return
        }
        let prevout: TransactionOutput
        if let witnessPrevout = ins[i].witnessPrevout {
            prevout = witnessPrevout
        } else if let prevoutTx = ins[i].prevoutTx {
            let outpoint = unsignedTx.ins[i].outpoint
            prevout = prevoutTx.outs[outpoint.out]
        } else {
            preconditionFailure() // TODO: Should fail signer checks
        }
        var signer = TransactionSigner(tx: unsignedTx, prevouts: [prevout], sighashType: sighashType)
        if let redeemScript = ins[i].redeemScript, let witnessScript = ins[i].witnessScript {
            signer.sign(input: i, redeemScript: redeemScript, witnessScript: witnessScript, with: [secretKey])
        } else if let redeemScript = ins[i].redeemScript {
            signer.sign(input: i, redeemScript: redeemScript, with: [secretKey])
        } else if let witnessScript = ins[i].witnessScript {
            signer.sign(input: i, witnessScript: witnessScript, with: [secretKey])
        } else {
            signer.sign(input: i, with: secretKey)
        }
        guard let lastSig = signer.lastSig else {
            return
        }
        ins[i].partialSigs[secretKey.pubkey] = lastSig
    }

    public mutating func update(out i: Int, _ key: PublicKey, _ path: DerivationPath) {
        outs[i].derivationPaths[key] = path
    }

    public mutating func combine(with other: PartiallySignedTx) {
        precondition(unsignedTx == other.unsignedTx)
        precondition(version == other.version)
        xpubDerivations.merge(other.xpubDerivations) { (current, _) in current }
        proprietaryInfo.merge(other.proprietaryInfo) { (current, _) in current }
        additionalTypes.merge(other.additionalTypes) { (current, _) in current }
        for i in ins.indices {
            ins[i].combine(with: other.ins[i])
        }
        for i in outs.indices {
            outs[i].combine(with: other.outs[i])
        }
    }

    public mutating func finalize() {
        for i in ins.indices {
            let psbtIn = ins[i]
            let prevout: TransactionOutput
            if let witnessPrevout = psbtIn.witnessPrevout {
                prevout = witnessPrevout
            } else if let prevoutTx = psbtIn.prevoutTx {
                let outpoint = unsignedTx.ins[i].outpoint
                prevout = prevoutTx.outs[outpoint.out]
            } else {
                preconditionFailure()
            }

            if prevout.script.isPayToPubkeyHash {
                guard case let .pushBytes(hash) = prevout.script.ops[2] else {
                    preconditionFailure()
                }
                let key: Data?
                for preimage in ins[i].hash160Preimages {
                    let hashB = Data(Hash160.hash(data: preimage))
                    if hash == hashB {
                        key = preimage
                        break
                    }
                }
                // TODO: Check for public key in Hash160 preimages
            } else if prevout.script.isPayToMultisig {
                guard case let .constant(threshold) = prevout.script.ops[0] else {
                    preconditionFailure()
                }
                guard ins[i].partialSigs.count == threshold else {
                    return
                }
                let sigs = ins[i].partialSigs.values
                ins[i].finalScriptSig = Script(sigs.map {
                    Script.Operation.pushBytes($0.data)
                })
            } else if prevout.script.isPayToScriptHash, let redeemScript = psbtIn.redeemScript, redeemScript.isPayToMultisig {

                guard case let .constant(threshold) = redeemScript.ops[0] else {
                    preconditionFailure()
                }
                guard ins[i].partialSigs.count == threshold else {
                    return
                }

                // TODO: Sort only for testing purposes
                let sigs = ins[i].partialSigs.values.map(\.data).sorted(by: {
                    $0.lexicographicallyPrecedes($1)
                })

                ins[i].finalScriptSig = .init(
                    [.zero] +
                    sigs.map { Script.Operation.pushBytes($0) } +
                    [.pushBytes(redeemScript.binaryData)]
                )
            } else if prevout.script.isPayToScriptHash, let redeemScript = psbtIn.redeemScript, redeemScript.isSegwit, redeemScript.isPayToWitnessScriptHash, let witness = psbtIn.witnessScript, witness.isPayToMultisig {

                guard case let .constant(threshold) = witness.ops[0] else {
                    preconditionFailure()
                }
                guard ins[i].partialSigs.count == threshold else {
                    return
                }
                // TODO: Sort only for testing purposes
                let sigs = ins[i].partialSigs.values.map(\.data).sorted(by: {
                    $0.lexicographicallyPrecedes($1)
                })

                ins[i].finalScriptSig = .init([.pushBytes(redeemScript.binaryData)])
                ins[i].finalScriptWitness = .init(
                    [ScriptBool.false.binaryData] +
                    sigs +
                    [witness.binaryData]
                )
            }

            ins[i].partialSigs = [:]
            ins[i].derivationPaths = [:]
            ins[i].hash160Preimages = []
            ins[i].hash256Preimages = []
            ins[i].proprietaryInfo = [:]
            ins[i].redeemScript = nil
            ins[i].ripemd160Preimages = []
            ins[i].sha256Preimages = []
            ins[i].sighashType = nil
            ins[i].witnessScript = nil
        }
    }

    public func extractTx() -> Transaction {
        var tx = unsignedTx
        for i in ins.indices {
            let psbtIn = ins[i]
            if let scriptSig = psbtIn.finalScriptSig {
                tx.ins[i].script = scriptSig
            }
            if let witness = psbtIn.finalScriptWitness {
                tx.ins[i].witness = witness
            }
        }
        return tx
    }

    private var globalMap: PSBTMap {
        var entries: KeyedValues = [:]
        entries[.init(PSBTGlobalKeyType.unsignedTx)] = unsignedTx.binaryData
        for (xpub, path) in xpubDerivations {
            entries[.init(PSBTGlobalKeyType.xpub, data: xpub.binaryData)] = path.binaryData
        }
        if version != .v0 {
            entries[.init(PSBTGlobalKeyType.version)] = version.binaryData
        }
        var proprietaryTypes = KeyedValues()
        for (id, subkey) in proprietaryInfo {
            for (k, v) in subkey {
                let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                proprietaryTypes[.init(PSBTGlobalKeyType.proprietary, data: keyData)] = v
            }
        }
        entries.merge(proprietaryTypes) { lhs, _ in lhs }
        entries.merge(additionalTypes) { lhs, _ in lhs }
        return .init(entries: entries)
    }

    private static let magic = Data([0x70, 0x73, 0x62, 0x74, 0xff])
}

private struct ProprietarySuperKey: Hashable, CustomBinaryCodable {

    init(id: Data, subkey: PSBTMap.Key) {
        self.id = id
        self.subkey = subkey
    }

    init(from decoder: inout BinaryDecoder, encoding: Never?) throws(PSBTMapError) {
        do {
            id = try decoder.decode(variable: true)
            subkey = try decoder.decode()
        } catch {
            throw .invalidValueEncoding
        }
    }

    let id: Data
    let subkey: PSBTMap.Key

    func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
        counter.count(id, variable: true)
        counter.count(subkey)
    }

    func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
        encoder.encode(id, variable: true)
        encoder.encode(subkey)
    }
}
