import Foundation
import BitcoinCrypto

/// The public keys or hashes in an output script (scriptPubkey) to match by the input script (scriptSig).
public typealias OutputScriptSolutions = [Data]

extension Script {

    /// Match pay-to-pubkey: [PUSHDATA(pubkey) OP_CHECKSIG]
    func matchPayToPubkey() -> Data? {
        let script = self
        guard script.ops.count == 2 else { return nil }
        if case let .pushBytes(pk) = script.ops[0], script.ops[1] == .checkSig {
            // Accept standard sizes: 33-byte compressed or 65-byte uncompressed
            if pk.count == PublicKey.compressedLength || pk.count == PublicKey.uncompressedLength {
                return pk
            }
        }
        return nil
    }

    // Match pay-to-pubkey-hash: OP_DUP OP_HASH160 PUSHDATA(20) OP_EQUALVERIFY OP_CHECKSIG
    func matchPayToPubkeyHash() -> Data? {
        let script = self
        guard script.ops.count == 5 else { return nil }
        guard script.ops[0] == .dup, script.ops[1] == .hash160 else { return nil }
        guard case let .pushBytes(hash) = script.ops[2], hash.count == 20 else { return nil }
        guard script.ops[3] == .equalVerify, script.ops[4] == .checkSig else { return nil }
        return hash
    }

    /// Match multisig: OP_M <pubkeys...> OP_N OP_CHECKMULTISIG
    /// Returns (required, pubkeys)
    func matchMultisig() -> (required: Int, pubkeys: [Data])? {
        let script = self
        let ops = script.ops
        guard ops.count >= 3, ops.last == .checkMultisig else { return nil }

        // First op must be OP_M
        guard case let .constant(m) = ops[0], m >= 1, m <= Script.maxMultisigPubkeys else { return nil }

        // Collect consecutive pubkey pushes until we reach OP_N
        var i = 1
        var keys = [Data]()
        while i < ops.count {
            switch ops[i] {
            case .pushBytes(let key):
                // Standard key sizes 33 or 65 bytes
                if key.count == PublicKey.compressedLength || key.count == PublicKey.uncompressedLength {
                    keys.append(key)
                    i += 1
                    continue
                } else {
                    return nil
                }
            case .constant(let n):
                // Expect OP_N here (number of keys), followed by OP_CHECKMULTISIG at the end
                let required = Int(m)
                let numKeys = Int(n)
                guard i == ops.count - 2, numKeys == keys.count, numKeys >= required, numKeys <= Script.maxMultisigPubkeys else {
                    return nil
                }
                return (required, keys)
            default:
                return nil
            }
        }
        return nil
    }

    /// Attempt to match BIP342-style MultiA (CHECKSIG/CHECKSIGADD ... OP_NUMEQUAL)
    /// Returns (threshold, keyspans) where keyspans are 32-byte x-only pubkeys.
    func matchMultiA() -> (threshold: Int, keys: [Data])? {
        guard !ops.isEmpty else { return nil }
        // Fast checks similar to the C++ code: starts with 32-byte push and ends with OP_NUMEQUAL
        guard case let .pushBytes(first) = ops.first!, first.count == PublicKey.xOnlyLength, ops.last == .numEqual else { return nil }

        var keys = [Data]()
        var i = 0
        // Parse pairs of (32-byte key, OP_CHECKSIG or OP_CHECKSIGADD)
        while i + 1 < ops.count {
            guard case let .pushBytes(k) = ops[i], k.count == PublicKey.xOnlyLength else { return nil }
            let next = ops[i + 1]
            if keys.isEmpty {
                guard next == .checkSig else { return nil }
            } else {
                guard next == .checkSigAdd else { return nil }
            }
            keys.append(k)
            i += 2
            // Stop before threshold/OP_NUMEQUAL tail
            if i >= ops.count { break }
            // Next should be threshold (constant), OP_NUMEQUAL, and then end
            if i + 1 < ops.count, case .constant = ops[i], ops[i + 1] == .numEqual {
                break
            }
        }
        guard !keys.isEmpty, keys.count <= Script.maxMultisigPubkeys else { return nil }

        // Expect threshold and OP_NUMEQUAL at the end
        guard ops.count >= 2, case let .constant(t) = ops[ops.count - 2], ops.last == .numEqual else { return nil }
        let threshold = Int(t)
        guard threshold >= 1, threshold <= keys.count else { return nil }
        return (threshold, keys)
    }

    /// Parse an output script (scriptPubKey) and identify script type for standard scripts.
    ///
    /// If successful, returns script type and parsed pubkeys or hashes, depending on the type.
    /// For example, for a P2SH script, the second element in the returned tuple will contain the script hash, for P2PKH it will contain the key hash, etc.
    public func solveOutputType() -> (OutputType, OutputScriptSolutions) {
        let scriptPubKey = self

        // P2SH: Shortcut for pay-to-script-hash, which are more constrained than the other types:
        // it is always OP_HASH160 20 [20 byte hash] OP_EQUAL
        if scriptPubKey.isPayToScriptHash {
            // Extract the 20-byte hash from OP_HASH160 <20> OP_EQUAL
            if case let .pushBytes(hash) = scriptPubKey.ops[1] {
                return (.scriptHash, [hash])
            }
            return (.nonStandard, [])
        }

        // Segwit programs
        if scriptPubKey.isSegwit {
            let version = scriptPubKey.witnessVersion
            let program = scriptPubKey.witnessProgram

            if version == 0 {
                if program.count == Hash160.Digest.byteCount { // 20 bytes
                    return (.witnessV0KeyHash, [program])
                }
                if program.count == SHA256.Digest.byteCount { // 32 bytes
                    return (.witnessV0ScriptHash, [program])
                }
                // v0 must be 20 or 32 in Core's solver
                return (.nonStandard, [])
            }

            if version == 1 && program.count == PublicKey.xOnlyLength { // 32-byte x-only
                return (.witnessV1Taproot, [program])
            }

            if scriptPubKey.isPayToAnchor {
                return (.anchor, [])
            }

            // Unknown witness version (Core returns WITNESS_UNKNOWN with [version, program])
            return (.witnessUnknown, [Data([UInt8(truncatingIfNeeded: version)]), program])
        }

        // Null data (OP_RETURN ...) and push-only after the first byte
        if !scriptPubKey.ops.isEmpty, scriptPubKey.ops[0] == .return, scriptPubKey.ops.dropFirst().allSatisfy({ $0.isPush }) {
            // Provably prunable, data-carrying output
            // So long as script passes the IsUnspendable() test and all but the first byte passes the IsPushOnly() test we don't care what exactly is in the script.
            return (.nullData, [])
        }

        // Pay-to-pubkey
        if let pk = scriptPubKey.matchPayToPubkey() {
            return (.pubkey, [pk])
        }

        // Pay-to-pubkey-hash
        if let hash = scriptPubKey.matchPayToPubkeyHash() {
            return (.pubkeyHash, [hash])
        }

        // Multisig
        if let (required, keys) = scriptPubKey.matchMultisig() {
            // Encode like Core: required (1 byte), keys..., key count (1 byte)
            var solutions = [Data([UInt8(required)])]
            solutions.append(contentsOf: keys)
            solutions.append(Data([UInt8(keys.count)]))
            return (.multisig, solutions)
        }
        return (.nonStandard, [])
    }
}
