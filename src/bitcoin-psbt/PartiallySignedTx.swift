import Foundation
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet

public enum PartiallySignedTxState: Equatable, Sendable {
    case created, complete
}

private typealias KeyedValues = [PSBTMap.Key : PSBTMap.Value]

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

        public init(prevoutTx: BitcoinTx? = nil, witnessPrevout: TxOut? = nil, redeemScript: BitcoinScript? = nil, witnessScript: BitcoinScript? = nil, proprietaryInfo: ProprietaryInfo = [:]) {
            self.prevoutTx = prevoutTx
            self.witnessPrevout = witnessPrevout
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
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
            var redeemScript = BitcoinScript?.none
            var witnessScript = BitcoinScript?.none
            var proprietaryInfo: ProprietaryInfo = [:]
            var additionalTypes: KeyedValues = [:]

            for (k, v) in map.entries {
                switch k.type {
                case PSBTInKeyType.nonWitnessUTXO.rawValue:
                    guard k.data.isEmpty else {
                        throw .invalidInputKeyData
                    }
                    guard let tx = try? BitcoinTx(binaryData: v.data) else {
                        throw .invalidInputPreviousTransaction
                    }
                    prevoutTx = tx
                case PSBTInKeyType.witnessUTXO.rawValue:
                    guard k.data.isEmpty else {
                        throw .invalidInputKeyData
                    }
                    guard let out = try? TxOut(binaryData: v.data) else {
                        throw PartiallySignedTxError.invalidInputPreviousOutput
                    }
                    witnessPrevout = out
                case PSBTInKeyType.redeemScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .invalidInputKeyData
                    }
                    guard let script = try? BitcoinScript(binaryData: v.data) else {
                        throw PartiallySignedTxError.invalidInputRedeemScript
                    }
                    redeemScript = script
                case PSBTInKeyType.witnessScript.rawValue:
                    guard k.data.isEmpty else {
                        throw .invalidInputKeyData
                    }
                    guard let script = try? BitcoinScript(binaryData: v.data) else {
                        throw PartiallySignedTxError.invalidInputWitnessScript
                    }
                    witnessScript = script
                case PSBTInKeyType.proprietary.rawValue:
                    guard let key = try? ProprietarySuperKey(binaryData: k.data) else { throw .invalidProprietaryKey }
                    if proprietaryInfo[key.id] == nil { proprietaryInfo[key.id] = [:] }
                    proprietaryInfo[key.id]![.init(key.subkey)] = v.data
                default:
                    additionalTypes[k] = v
                }
            }

            guard prevoutTx != .none || witnessPrevout != .none else {
                throw PartiallySignedTxError.missingPreviousOutput
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
                    guard witnessPrevout.script.isSegwit  else {
                    // TODO: check redeem script is segwit
                        throw .nonSegwitPreviousOutput
                    }
                }
            }

            self.prevoutTx = prevoutTx
            self.witnessPrevout = witnessPrevout
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
            self.proprietaryInfo = proprietaryInfo
            self.additionalTypes = additionalTypes
        }

        public let prevoutTx: BitcoinTx?
        public let witnessPrevout: TxOut?
        public let redeemScript: BitcoinScript?
        public let witnessScript: BitcoinScript?
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
                entries[.init(PSBTInKeyType.nonWitnessUTXO)] = .init(data: prevoutTx.binaryData)
            }
            if let witnessPrevout {
                entries[.init(PSBTInKeyType.witnessUTXO)] = .init(data: witnessPrevout.binaryData)
            }
            if let redeemScript {
                entries[.init(PSBTInKeyType.redeemScript)] = .init(data: redeemScript.binaryData)
            }
            if let witnessScript {
                entries[.init(PSBTInKeyType.witnessScript)] = .init(data: witnessScript.binaryData)
            }
            var proprietaryTypes: KeyedValues = [:]
            for (id, subkey) in proprietaryInfo {
                for (k, v) in subkey {
                    let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                    proprietaryTypes[.init(PSBTInKeyType.proprietary, data: keyData)] = .init(data: v)
                }
            }
            entries.merge(proprietaryTypes) { lhs, _ in lhs }
            entries.merge(additionalTypes) { lhs, _ in lhs }
            return .init(entries: entries)
        }
    }

    public struct Out: Equatable, Sendable, CustomBinaryCodable {

        public init(redeemScript: BitcoinScript? = nil, witnessScript: BitcoinScript? = nil, proprietaryInfo: ProprietaryInfo = [:]) {
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
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
            var proprietaryInfo: ProprietaryInfo = [:]
            var additionalTypes: KeyedValues = [:]
            for (k, v) in map.entries {
                switch k.type {
                case PSBTOutKeyType.redeemScript.rawValue:
                    guard let script = try? BitcoinScript(binaryData: v.data) else {
                        throw PartiallySignedTxError.invalidOutputRedeemScript
                    }
                    redeemScript = script
                case PSBTOutKeyType.witnessScript.rawValue:
                    guard let script = try? BitcoinScript(binaryData: v.data) else {
                        throw PartiallySignedTxError.invalidOutputWitnessScript
                    }
                    witnessScript = script
                case PSBTOutKeyType.proprietary.rawValue:
                    guard let key = try? ProprietarySuperKey(binaryData: k.data) else { throw .invalidProprietaryKey }
                    if proprietaryInfo[key.id] == nil { proprietaryInfo[key.id] = [:] }
                    proprietaryInfo[key.id]![.init(key.subkey)] = v.data
                default:
                    additionalTypes[k] = v
                }
            }
            self.redeemScript = redeemScript
            self.witnessScript = witnessScript
            self.proprietaryInfo = proprietaryInfo
            self.additionalTypes = additionalTypes
        }

        public let redeemScript: BitcoinScript?
        public let witnessScript: BitcoinScript?
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
            if let redeemScript {
                entries[.init(PSBTOutKeyType.redeemScript)] = .init(data: redeemScript.binaryData)
            }
            if let witnessScript {
                entries[.init(PSBTOutKeyType.witnessScript)] = .init(data: witnessScript.binaryData)
            }
            var proprietaryTypes = KeyedValues()
            for (id, subkey) in proprietaryInfo {
                for (k, v) in subkey {
                    let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                    proprietaryTypes[.init(PSBTOutKeyType.proprietary, data: keyData)] = .init(data: v)
                }
            }
            entries.merge(proprietaryTypes) { lhs, _ in lhs }
            entries.merge(additionalTypes) { lhs, _ in lhs }
            return .init(entries: entries)
        }
    }

    public init(tx: BitcoinTx, xpubs: [ExtendedKey] = [], proprietaryInfo: ProprietaryInfo = [:], ins: [In], outs: [Out]) {
        // TODO: Maybe extract signatures from signed transaction?
        precondition(tx.ins.allSatisfy { $0.witness.elements.isEmpty })
        precondition(tx.ins.allSatisfy { $0.script == .empty })
        precondition(ins.count == tx.ins.count)
        precondition(outs.count == tx.outs.count)
        version = .v0
        unsignedTx = tx
        self.xpubs = xpubs
        self.proprietaryInfo = proprietaryInfo
        additionalTypes = [:]
        self.ins = ins
        self.outs = outs
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
        var proprietaryInfo: ProprietaryInfo = [:]
        var additionalTypes: KeyedValues = [:]
        for (k, v) in globalMap.entries {
            switch k.type {
            case PSBTGlobalKeyType.unsignedTx.rawValue:
                guard k.data.isEmpty else {
                    throw .invalidUnsignedTransactionKey
                }
                do {
                    tx = try BitcoinTx(binaryData: v.data, encoding: .nonWitness)
                } catch {
                    throw .invalidUnsignedTransaction
                }
            case PSBTGlobalKeyType.xpub.rawValue:
                break
            case PSBTGlobalKeyType.version.rawValue:
                guard k.data.isEmpty else {
                    throw .invalidUnsignedVersionKey
                }
                do {
                    version = try Version(binaryData: v.data)
                } catch {
                    throw .invalidVersionEncoding
                }
            case PSBTGlobalKeyType.proprietary.rawValue:
                guard let key = try? ProprietarySuperKey(binaryData: k.data) else { throw .invalidProprietaryKey }
                if proprietaryInfo[key.id] == nil { proprietaryInfo[key.id] = [:] }
                proprietaryInfo[key.id]![.init(key.subkey)] = v.data
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
        unsignedTx = tx

        // PSBT Version Number
        // Version will be required in V2: `guard let versionValue = globalMap.values[Version.key] else { throw .missingVersion }`
        if let version {
            guard version == .v0 else {
                throw .invalidVersion // Only v0 supported for now
            }
            self.version = version
        } else {
            self.version = .v0
        }

        xpubs = [] // TODO: remove
        self.proprietaryInfo = proprietaryInfo
        self.additionalTypes = additionalTypes

        var ins: [In] = []
        for _ in tx.ins {
            ins.append(try In(from: &decoder, encoding: .none))
        }
        self.ins = ins

        var outs: [Out] = []
        for _ in tx.outs {
            outs.append(try Out(from: &decoder, encoding: .none))
        }
        self.outs = outs
    }

    public let version: Version
    public let unsignedTx: BitcoinTx
    public let xpubs: [ExtendedKey]
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
        var entries: KeyedValues = [
            version.keypair.key: version.keypair.value,
            .init(PSBTGlobalKeyType.unsignedTx): .init(data: unsignedTx.binaryData)
            // TODO: add xpubs
        ]
        var proprietaryTypes = KeyedValues()
        for (id, subkey) in proprietaryInfo {
            for (k, v) in subkey {
                let keyData = ProprietarySuperKey(id: id, subkey: .init(type: k.type, data: k.data)).binaryData
                proprietaryTypes[.init(PSBTGlobalKeyType.proprietary, data: keyData)] = .init(data: v)
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
