import Foundation
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet

public enum PartiallySignedTxState: Equatable, Sendable {
    case created, complete
}

private typealias KeyedValues = [PSBTMap.Key : Data]

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
            partialSigs: [PubKey : AnySig] = [:],
            sighashType: SighashType? = nil,
            redeemScript: BitcoinScript? = nil,
            witnessScript: BitcoinScript? = nil,
            derivationPaths: [PubKey : DerivationPath] = [:],
            finalScriptSig: BitcoinScript? = nil,
            finalScriptWitness: BitcoinScript? = nil,
            ripemd160Preimages: [Data] = [],
            sha256Preimages: [Data] = [],
            hash160Preimages: [Data] = [],
            hash256Preimages: [Data] = [],
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

            var partialSigs = [PubKey : AnySig]()
            var sighashType = SighashType?.none

            var redeemScript = BitcoinScript?.none
            var witnessScript = BitcoinScript?.none

            var derivationPaths = [PubKey: DerivationPath]()

            var finalScriptSig = BitcoinScript?.none
            var finalScriptWitness = BitcoinScript?.none

            var ripemd160Preimages = [Data]()
            var sha256Preimages = [Data]()
            var hash160Preimages = [Data]()
            var hash256Preimages = [Data]()

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
                    guard let sig = AnySig(v) else {
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
                    guard let script = try? BitcoinScript(binaryData: v) else {
                        throw .invalidInputFinalScriptWitness
                    }
                    finalScriptWitness = script
                case PSBTInKeyType.ripemd160Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(RIPEMD160.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    ripemd160Preimages.append(preimage)
                case PSBTInKeyType.sha256Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(SHA256.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    sha256Preimages.append(preimage)
                case PSBTInKeyType.hash160Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(Hash160.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    hash160Preimages.append(preimage)
                case PSBTInKeyType.hash256Preimage.rawValue:
                    let hash = k.data
                    let preimage = v
                    guard Data(Hash256.hash(data: preimage)) == hash else {
                        throw .hashPreimageMismatch
                    }
                    hash256Preimages.append(preimage)
                case PSBTInKeyType.proprietary.rawValue:
                    guard let key = try? ProprietarySuperKey(binaryData: k.data) else { throw .invalidProprietaryKey }
                    if proprietaryInfo[key.id] == nil { proprietaryInfo[key.id] = [:] }
                    proprietaryInfo[key.id]![.init(key.subkey)] = v
                default:
                    additionalTypes[k] = v
                }
            }

            if let witnessPrevout {
                if witnessPrevout.script.isPayToScriptHash {
                    guard let redeemScript else {
                        throw .missingInputRedeemScript
                    }
                    guard redeemScript.isSegwit else {
                        throw .nonSegwitPreviousOutput
                    }
                } else {
                    guard witnessPrevout.script.isSegwit else {
                        throw .nonSegwitPreviousOutput
                    }
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

        public let prevoutTx: BitcoinTx?
        public let witnessPrevout: TxOut?
        public let partialSigs: [PubKey : AnySig]
        public let sighashType: SighashType?
        public let redeemScript: BitcoinScript?
        public let witnessScript: BitcoinScript?
        public let derivationPaths: [PubKey: DerivationPath]
        public let finalScriptSig: BitcoinScript?
        public let finalScriptWitness: BitcoinScript?
        public let ripemd160Preimages: [Data]
        public let sha256Preimages: [Data]
        public let hash160Preimages: [Data]
        public let hash256Preimages: [Data]
        public let proprietaryInfo: ProprietaryInfo

        private let additionalTypes: KeyedValues

        public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
            counter.count(map)
        }

        public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
            encoder.encode(map)
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

        public let redeemScript: BitcoinScript?
        public let witnessScript: BitcoinScript?
        public let derivationPaths: [PubKey : DerivationPath]
        public let proprietaryInfo: ProprietaryInfo

        private let additionalTypes: KeyedValues

        public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
            counter.count(map)
        }

        public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
            encoder.encode(map)
        }

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
    }

    public init(tx: BitcoinTx, xpubDerivations: [ExtendedKey : DerivationPath] = [:], proprietaryInfo: ProprietaryInfo = [:], ins: [In], outs: [Out]) throws(PartiallySignedTxError) {
        try self.init(tx: tx, xpubDerivations: xpubDerivations, proprietaryInfo: proprietaryInfo, ins: ins, outs: outs, additionalTypes: [:])
    }

    private init(tx: BitcoinTx, xpubDerivations: [ExtendedKey : DerivationPath], proprietaryInfo: ProprietaryInfo, ins: [In], outs: [Out], additionalTypes: KeyedValues) throws(PartiallySignedTxError) {
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
        try self.init(tx: tx, xpubDerivations: xpubDerivations, proprietaryInfo: proprietaryInfo, ins: ins, outs: outs, additionalTypes: additionalTypes)
    }

    public let version = Version.v0
    public let unsignedTx: BitcoinTx
    public let xpubDerivations: [ExtendedKey : DerivationPath]
    public let proprietaryInfo: ProprietaryInfo
    public let ins: [In]
    public let outs: [Out]

    private let additionalTypes: KeyedValues

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
