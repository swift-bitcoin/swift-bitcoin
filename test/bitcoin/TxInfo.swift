import Foundation

struct TxInfo: Equatable, Decodable {
    init(txid: String, hash: String, version: Int, size: Int, vsize: Int, weight: Int, locktime: Int, vin: [TxInfo.Input], vout: [TxInfo.Output], hex: String, blockhash: String?, confirmations: Int?, time: Date?, blocktime: Int?) {
        self.txid = txid
        self.hash = hash
        self.version = version
        self.size = size
        self.vsize = vsize
        self.weight = weight
        self.locktime = locktime
        self.vin = vin
        self.vout = vout
        self.hex = hex
        self.blockhash = blockhash
        self.confirmations = confirmations
        self.time = time
        self.blocktime = blocktime
    }

    let txid: String
    let hash: String
    let version: Int
    let size: Int
    let vsize: Int
    let weight: Int
    let locktime: Int
    let vin: [Input]
    let vout: [Output]
    let hex: String
    let blockhash: String?
    let confirmations: Int?
    let time: Date?
    let blocktime: Int?
}

extension TxInfo {
    struct Input: Equatable, Decodable {
         init(coinbase: String? = nil, scriptSig: TxInfo.Input.UnlockScript? = nil, txid: String? = nil, vout: Int? = nil, txinwitness: [String]? = nil, sequence: Int) {
            self.coinbase = coinbase
            self.scriptSig = scriptSig
            self.txid = txid
            self.vout = vout
            self.txinwitness = txinwitness
            self.sequence = sequence
        }

        struct UnlockScript: Equatable, Decodable {
            init(asm: String, hex: String) {
                self.asm = asm
                self.hex = hex
            }

            let asm: String
            let hex: String
        }

        // Either coinbase (scriptsig)
        let coinbase: String?

        // Either scriptsig
        let scriptSig: UnlockScript?
        let txid: String?
        let vout: Int?

        let txinwitness: [String]?
        let sequence: Int
    }

    struct Output: Equatable, Decodable {
        init(value: Double, n: Int, scriptPubKey: TxInfo.Output.LockScript) {
            self.value = value
            self.n = n
            self.scriptPubKey = scriptPubKey
        }

        struct LockScript: Equatable, Decodable {
            init(asm: String, desc: String, hex: String, address: String? = nil, type: LockType) {
                self.asm = asm
                self.desc = desc
                self.hex = hex
                self.address = address
                self.type = type
            }

            enum LockType: String, Equatable, Decodable {
                case nonStandard = "nonstandard",
                     publicKey = "pubkey",
                     publicKeyHash = "pubkeyhash",
                     scriptHash = "scripthash",
                     multiSig = "multisig",
                     nullData = "nulldata",
                     witnessV0KeyHash = "witness_v0_keyhash",
                     witnessV0ScriptHash = "witness_v0_scripthash",
                     witnessV1TapRoot = "witness_v1_taproot",
                     witnessUnknown = "witness_unknown",
                     unknown
            }

            let asm: String
            let desc: String
            let hex: String
            let address: String?
            let type: LockType
        }

        let value: Double
        let n: Int
        let scriptPubKey: LockScript
    }
}
