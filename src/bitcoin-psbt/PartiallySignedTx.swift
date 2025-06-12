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
            prevoutTx: BitcoinTx? = nil,
            witnessPrevout: TxOut? = nil,
            partialSigs: [PubKey : ExtendedSig] = [:],
            sighashType: SighashType? = nil,
            redeemScript: BitcoinScript? = nil,
            witnessScript: BitcoinScript? = nil,
            derivationPaths: [PubKey : DerivationPath] = [:],
            finalScriptSig: BitcoinScript? = nil,
            finalScriptWitness: TxWitness? = nil,
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
            var prevoutTx = BitcoinTx?.none
            var witnessPrevout = TxOut?.none

            var partialSigs = [PubKey : ExtendedSig]()
            var sighashType = SighashType?.none

            var redeemScript = BitcoinScript?.none
            var witnessScript = BitcoinScript?.none

            var derivationPaths = [PubKey: DerivationPath]()

            var finalScriptSig = BitcoinScript?.none
            var finalScriptWitness = TxWitness?.none

            var ripemd160Preimages = Set<Data>()
            var sha256Preimages = Set<Data>()
            var hash160Preimages = Set<Data>()
            var hash256Preimages = Set<Data>()

            var proprietaryInfo: ProprietaryInfo = [:]
            var additionalTypes: KeyedValues = [:]

            for (k, v) in map.entries {
                switch k.type {
                case PSBTInKeyType.nonWitnessUTXO.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Non-witness UTXO")
                    }
                    guard let tx = try? BitcoinTx(binaryData: v) else {
                        throw .invalidInputPreviousTransaction
                    }
                    prevoutTx = tx
                case PSBTInKeyType.witnessUTXO.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Witness UTXO")
                    }
                    guard let out = try? TxOut(binaryData: v) else {
                        throw .invalidInputPreviousOutput
                    }
                    witnessPrevout = out
                case PSBTInKeyType.partialSig.rawValue:
                    guard let pubkey = PubKey(k.data) else {
                        throw .invalidPublicKey
                    }
                    guard let sig = ExtendedSig(v) else {
                        throw .invalidSignature
                    }
                    partialSigs[pubkey] = sig
                case PSBTInKeyType.sighashType.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Sighath type")
                    }
                    guard v.count == 4, let s = try? SighashType(binaryData: v, encoding: .fullLength) else {
                        throw .invalidInputSighashType
                    }
                    sighashType = s
                case PSBTInKeyType.redeemScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Redeem script")
                    }
                    guard let script = try? BitcoinScript(binaryData: v) else {
                        throw .invalidInputRedeemScript
                    }
                    redeemScript = script
                case PSBTInKeyType.witnessScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Witness script")
                    }
                    guard let script = try? BitcoinScript(binaryData: v) else {
                        throw .invalidInputWitnessScript
                    }
                    witnessScript = script
                case PSBTInKeyType.derivationPath.rawValue:
                    guard let pubkey = PubKey(k.data) else {
                        throw .invalidPublicKey
                    }
                    guard let path = try? DerivationPath(binaryData: v) else {
                        throw .invalidPublicKeyDerivation
                    }
                    derivationPaths[pubkey] = path
                case PSBTInKeyType.finalScriptSig.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Final scriptSig")
                    }
                    guard let script = try? BitcoinScript(binaryData: v) else {
                        throw .invalidInputFinalScriptSig
                    }
                    finalScriptSig = script
                case PSBTInKeyType.finalScriptWitness.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyInputKeyData("Final script witness")
                    }
                    guard let script = try? TxWitness(binaryData: v) else {
                        throw .invalidInputFinalScriptWitness
                    }
                    finalScriptWitness = script
                case PSBTInKeyType.ripemd160Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(RIPEMD160.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    ripemd160Preimages.insert(preimage)
                case PSBTInKeyType.sha256Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(SHA256.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    sha256Preimages.insert(preimage)
                case PSBTInKeyType.hash160Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(Hash160.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    hash160Preimages.insert(preimage)
                case PSBTInKeyType.hash256Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(Hash256.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    hash256Preimages.insert(preimage)
                case PSBTInKeyType.proprietary.rawValue:
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

        public internal(set) var prevoutTx: BitcoinTx?
        public internal(set) var witnessPrevout: TxOut?
        public internal(set) var partialSigs: [PubKey : ExtendedSig]
        public internal(set) var sighashType: SighashType?
        public internal(set) var redeemScript: BitcoinScript?
        public internal(set) var witnessScript: BitcoinScript?
        public internal(set) var derivationPaths: [PubKey: DerivationPath]
        public internal(set) var finalScriptSig: BitcoinScript?
        public internal(set) var finalScriptWitness: TxWitness?
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
            if witnessPrevout == .none, let newValue = other.witnessPrevout {
                witnessPrevout = newValue
            }
            partialSigs.merge(other.partialSigs) { (current, _) in current }
            if sighashType == Optional.none, let newValue = other.sighashType {
                sighashType = newValue
            }
            if redeemScript == .none, let newValue = other.redeemScript {
                redeemScript = newValue
            }
            if witnessScript == .none, let newValue = other.witnessScript {
                witnessScript = newValue
            }
            derivationPaths.merge(other.derivationPaths) { (current, _) in current }
            if finalScriptSig == .none, let newValue = other.finalScriptSig {
                finalScriptSig = newValue
            }
            if finalScriptWitness == .none, let newValue = other.finalScriptWitness {
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
                entries[.init(PSBTInKeyType.nonWitnessUTXO)] = prevoutTx.binaryData
            }
            if let witnessPrevout {
                entries[.init(PSBTInKeyType.witnessUTXO)] = witnessPrevout.binaryData
            }
            for (k, s) in partialSigs {
                entries[.init(PSBTInKeyType.partialSig, data: k.data)] = s.data
            }
            if let sighashType {
                entries[.init(PSBTInKeyType.sighashType)] = sighashType.binaryData(encoding: .fullLength)
            }
            if let redeemScript {
                entries[.init(PSBTInKeyType.redeemScript)] = redeemScript.binaryData
            }
            if let witnessScript {
                entries[.init(PSBTInKeyType.witnessScript)] = witnessScript.binaryData
            }
            for (k, p) in derivationPaths {
                entries[.init(PSBTInKeyType.derivationPath, data: k.data)] = p.binaryData
            }
            if let finalScriptSig {
                entries[.init(PSBTInKeyType.finalScriptSig)] = finalScriptSig.binaryData
            }
            if let finalScriptWitness {
                entries[.init(PSBTInKeyType.finalScriptWitness)] = finalScriptWitness.binaryData
            }
            for preimage in ripemd160Preimages {
                entries[.init(PSBTInKeyType.ripemd160Preimage, data: Data(RIPEMD160.hash(data: preimage)))] = preimage
            }
            for preimage in sha256Preimages {
                entries[.init(PSBTInKeyType.sha256Preimage, data: Data(SHA256.hash(data: preimage)))] = preimage
            }
            for preimage in hash160Preimages {
                entries[.init(PSBTInKeyType.hash160Preimage, data: Data(Hash160.hash(data: preimage)))] = preimage
            }
            for preimage in hash256Preimages {
                entries[.init(PSBTInKeyType.hash256Preimage, data: Data(Hash256.hash(data: preimage)))] = preimage
            }
            var proprietaryTypes: KeyedValues = [:]
            for (id, subkey) in proprietaryInfo {
                for (k, v) in subkey {
                    let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                    proprietaryTypes[.init(PSBTInKeyType.proprietary, data: keyData)] = v
                }
            }
            entries.merge(proprietaryTypes) { lhs, _ in lhs }
            entries.merge(additionalTypes) { lhs, _ in lhs }
            return .init(entries: entries)
        }
    }

    public struct Out: Equatable, Sendable, CustomBinaryCodable {

        public init(
            redeemScript: BitcoinScript? = nil,
            witnessScript: BitcoinScript? = nil,
            derivationPaths: [PubKey : DerivationPath] = [:],
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
            var redeemScript = BitcoinScript?.none
            var witnessScript = BitcoinScript?.none

            var derivationPaths = [PubKey : DerivationPath]()

            var proprietaryInfo: ProprietaryInfo = [:]
            var additionalTypes: KeyedValues = [:]
            for (k, v) in map.entries {
                switch k.type {
                case PSBTOutKeyType.redeemScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyOutputKeyData("Redeem script")
                    }
                    guard let script = try? BitcoinScript(binaryData: v) else {
                        throw .invalidOutputRedeemScript
                    }
                    redeemScript = script
                case PSBTOutKeyType.witnessScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .nonEmptyOutputKeyData("Witness script")
                    }
                    guard let script = try? BitcoinScript(binaryData: v) else {
                        throw .invalidOutputWitnessScript
                    }
                    witnessScript = script
                case PSBTOutKeyType.derivationPath.rawValue:
                    guard let pubkey = PubKey(k.data) else {
                        throw .invalidPublicKey
                    }
                    guard let path = try? DerivationPath(binaryData: v) else {
                        throw .invalidPublicKeyDerivation
                    }
                    derivationPaths[pubkey] = path
                case PSBTOutKeyType.proprietary.rawValue:
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

        public internal(set) var redeemScript: BitcoinScript?
        public internal(set) var witnessScript: BitcoinScript?
        public internal(set) var derivationPaths: [PubKey : DerivationPath]
        public internal(set) var proprietaryInfo: ProprietaryInfo

        private var additionalTypes: KeyedValues

        public var isEmpty: Bool {
            redeemScript == nil && witnessScript == nil && derivationPaths.isEmpty && proprietaryInfo.isEmpty && additionalTypes.isEmpty
        }

        var map: PSBTMap {
            var entries: KeyedValues = [:]
            if let redeemScript {
                entries[.init(PSBTOutKeyType.redeemScript)] = redeemScript.binaryData
            }
            if let witnessScript {
                entries[.init(PSBTOutKeyType.witnessScript)] = witnessScript.binaryData
            }
            for (k, p) in derivationPaths {
                entries[.init(PSBTOutKeyType.derivationPath, data: k.data)] = p.binaryData
            }
            var proprietaryTypes = KeyedValues()
            for (id, subkey) in proprietaryInfo {
                for (k, v) in subkey {
                    let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                    proprietaryTypes[.init(PSBTOutKeyType.proprietary, data: keyData)] = v
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
            if redeemScript == .none, let newValue = other.redeemScript {
                redeemScript = newValue
            }
            if witnessScript == .none, let newValue = other.witnessScript {
                witnessScript = newValue
            }
            derivationPaths.merge(other.derivationPaths) { (current, _) in current }
            proprietaryInfo.merge(other.proprietaryInfo) { (current, _) in current }
            additionalTypes.merge(other.additionalTypes) { (current, _) in current }
        }
    }

    public init(_ tx: BitcoinTx, xpubDerivations: [ExtendedKey : DerivationPath] = [:], proprietaryInfo: ProprietaryInfo = [:], ins: [In]? = .none, outs: [Out]? = .none) throws(PartiallySignedTxError) {
        try self.init(tx, xpubDerivations: xpubDerivations, proprietaryInfo: proprietaryInfo, ins: ins, outs: outs, additionalTypes: [:])
    }

    private init(_ tx: BitcoinTx, xpubDerivations: [ExtendedKey : DerivationPath], proprietaryInfo: ProprietaryInfo, ins: [In]? = .none, outs: [Out]? = .none, additionalTypes: KeyedValues) throws(PartiallySignedTxError) {
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
            let txIn = unsignedTx.ins[i]
            if let prevoutTx = ins[i].prevoutTx {
                guard txIn.outpoint.txID == prevoutTx.id else {
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

        var tx = BitcoinTx?.none
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
                    tx = try BitcoinTx(binaryData: v, encoding: .nonWitness)
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
            ins.append(try In(from: &decoder, encoding: .none))
        }

        var outs: [Out] = []
        for _ in tx.outs {
            outs.append(try Out(from: &decoder, encoding: .none))
        }
        try self.init(tx, xpubDerivations: xpubDerivations, proprietaryInfo: proprietaryInfo, ins: ins, outs: outs, additionalTypes: additionalTypes)
    }

    public let version = Version.v0
    public let unsignedTx: BitcoinTx
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
        for txIn in ins {
            counter.count(txIn)
        }
        for out in outs {
            counter.count(out)
        }
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
        encoder.encode(Self.magic)
        encoder.encode(globalMap)
        for txIn in ins {
            encoder.encode(txIn)
        }
        for out in outs {
            encoder.encode(out)
        }
    }

    public mutating func update(in i: Int, _ tx: BitcoinTx) {
        ins[i].prevoutTx = tx
    }

    public mutating func update(in i: Int, _ out: TxOut) {
        ins[i].witnessPrevout = out
    }

    public mutating func update(in i: Int, redeemScript: BitcoinScript) {
        ins[i].redeemScript = redeemScript
    }

    public mutating func update(in i: Int, witnessScript: BitcoinScript) {
        ins[i].witnessScript = witnessScript
    }

    public mutating func update(in i: Int, _ key: PubKey, _ path: DerivationPath) {
        ins[i].derivationPaths[key] = path
    }

    public mutating func update(in i: Int, _ sighashType: SighashType) {
        ins[i].sighashType = sighashType
    }

    public func checkForSigning() throws(PartiallySignedTxError) {
        for (txIn, psbtIn) in zip(unsignedTx.ins, ins) {
            if let witnessPrevout = psbtIn.witnessPrevout {
                let isPayToWitnessScriptHash: Bool
                let witnessProgram: BitcoinScript
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
                    let prevout = prevoutTx.outs[txIn.outpoint.txOut]
                    guard prevout == witnessPrevout else {
                        throw .invalidInputPreviousOutput
                    }
                }
            } else {
                // A witness previous output was _not_ provided.
                guard let prevoutTx = psbtIn.prevoutTx else {
                    throw .missingPreviousOutput
                }
                let prevout = prevoutTx.outs[txIn.outpoint.txOut]
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

    public mutating func sign(in i: Int, using secretKey: SecretKey) throws(PartiallySignedTxError) {

        // Signer checks for all inputs
        try checkForSigning()

        guard let sighashType = ins[i].sighashType else {
            return
        }
        let prevout: TxOut
        if let witnessPrevout = ins[i].witnessPrevout {
            prevout = witnessPrevout
        } else if let prevoutTx = ins[i].prevoutTx {
            let outpoint = unsignedTx.ins[i].outpoint
            prevout = prevoutTx.outs[outpoint.txOut]
        } else {
            preconditionFailure() // TODO: Should fail signer checks
        }
        var signer = TxSigner(tx: unsignedTx, prevouts: [prevout], sighashType: sighashType)
        if let redeemScript = ins[i].redeemScript, let witnessScript = ins[i].witnessScript {
            signer.sign(txIn: i, redeemScript: redeemScript, witnessScript: witnessScript, with: [secretKey])
        } else if let redeemScript = ins[i].redeemScript {
            signer.sign(txIn: i, redeemScript: redeemScript, with: [secretKey])
        } else if let witnessScript = ins[i].witnessScript {
            signer.sign(txIn: i, witnessScript: witnessScript, with: [secretKey])
        } else {
            signer.sign(txIn: i, with: secretKey)
        }
        guard let lastSig = signer.lastSig else {
            return
        }
        ins[i].partialSigs[secretKey.pubkey] = lastSig
    }

    public mutating func update(out i: Int, _ key: PubKey, _ path: DerivationPath) {
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
            let prevout: TxOut
            if let witnessPrevout = psbtIn.witnessPrevout {
                prevout = witnessPrevout
            } else if let prevoutTx = psbtIn.prevoutTx {
                let outpoint = unsignedTx.ins[i].outpoint
                prevout = prevoutTx.outs[outpoint.txOut]
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
                ins[i].finalScriptSig = BitcoinScript(sigs.map {
                    ScriptOp.pushBytes($0.data)
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
                    sigs.map { ScriptOp.pushBytes($0) } +
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

    public func extractTx() -> BitcoinTx {
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
