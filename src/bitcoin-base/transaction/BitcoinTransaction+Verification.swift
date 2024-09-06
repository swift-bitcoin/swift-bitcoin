import Foundation
import BitcoinCrypto

// TODO: Deduplicate these variables which also exist on SignatureHash.swift
private let taprootControlBaseSize = 33
private let taprootControlNodeSize = 32

/// Transaction inputs/scripts verification.
extension BitcoinTransaction {

    // MARK: - Instance Methods

    public func verifyScript(prevouts: [TransactionOutput], config: ScriptConfig = .standard) -> Bool {
        var context = ScriptContext(config, transaction: self, prevouts: prevouts)
        for i in inputs.indices {
            context.inputIndex = i
            do {
                try verifyScript(&context)
            } catch {
                print("\(error) \(error.localizedDescription)")
                return false
            }
        }
        return true
    }

    /// Initial simplified version of transaction verification that allows for script execution.
    func verifyScript(_ context: inout ScriptContext) throws {
        let inputIndex = context.inputIndex
        let prevouts = context.prevouts
        let config = context.config

        precondition(context.transaction == self && prevouts.count == inputs.count)

        let scriptSig = inputs[inputIndex].script
        let scriptPubKey = prevouts[inputIndex].script

        // BIP16
        let isPayToScriptHash = config.contains(.payToScriptHash) && scriptPubKey.isPayToScriptHash

        // BIP141
        let isNativeSegwit = config.contains(.witness) && scriptPubKey.isSegwit
        let isSegwit: Bool
        let witnessVersion: Int?
        let witnessProgram: Data?

        // The scriptSig must be exactly empty or validation fails.
        if isNativeSegwit && !scriptSig.isEmpty {
            throw ScriptError.scriptSigNotEmpty
        }

        // BIP62, BIP16
        if config.contains(.pushOnly) || isPayToScriptHash {
            try scriptSig.checkPushOnly()
        }

        if isNativeSegwit {
            isSegwit = true
            witnessVersion = scriptPubKey.witnessVersion
            witnessProgram = scriptPubKey.witnessProgram
        } else {
            // Execute scriptSig
            try context.run(scriptSig)
            let stackTmp = context.stack // BIP16

            // scriptSig and scriptPubKey must be evaluated sequentially on the same stack rather than being simply concatenated (see CVE-2010-5141)
            try context.run(scriptPubKey, stack: stackTmp)
            if let last = context.stack.last, !ScriptBoolean(last).value {
                throw ScriptError.falseReturned
            }

            // BIP16
            if isPayToScriptHash {
                var stack = stackTmp
                guard let data = stack.popLast() else { preconditionFailure() }

                let redeemScript = BitcoinScript(data)

                // BIP141 - P2SH witness program
                if redeemScript.isSegwit {
                    isSegwit = true
                    witnessVersion = redeemScript.witnessVersion
                    witnessProgram = redeemScript.witnessProgram

                    // The scriptSig must be exactly a push of the BIP16 redeemScript or validation fails.
                    if !stack.isEmpty {
                        // We already checked that scriptSig was push only.
                        throw ScriptError.scriptSigTooManyPushes
                    }
                } else {
                    isSegwit = false
                    witnessVersion = .none
                    witnessProgram = .none

                    try context.run(redeemScript, stack: stack)
                    if let last = context.stack.last, !ScriptBoolean(last).value {
                        throw ScriptError.falseReturned
                    }
                }

            } else {
                isSegwit = false
                witnessVersion = .none
                witnessProgram = .none
            }

            if !isSegwit && config.contains(.cleanStack) && context.stack.count != 1 { // BIP62, BIP16
                throw ScriptError.uncleanStack
            }
        }

        // BIP141
        if isSegwit {
            guard let witnessVersion, let witnessProgram else { preconditionFailure() }
            if witnessVersion == 0 {
                try verifyWitness(&context, witnessVersion: witnessVersion, witnessProgram: witnessProgram)
            } else if witnessVersion == 1 && witnessProgram.count == 32 && !isPayToScriptHash {
                // BIP341
                try verifyTaproot(&context, witnessVersion: witnessVersion, witnessProgram: witnessProgram)
            } else if config.contains(.discourageUpgradableWitnessProgram) {
                throw ScriptError.disallowedWitnessVersion
            }
            // If the version byte is 2 to 16, no further interpretation of the witness program or witness stack happens
        }
    }

    private func verifyWitness(_ context: inout ScriptContext, witnessVersion: Int, witnessProgram: Data) throws {
        let inputIndex = context.inputIndex

        guard var stack = inputs[inputIndex].witness?.elements else { preconditionFailure() }

        if witnessProgram.count == Hash160.Digest.byteCount /* 20 */ {
            // If the version byte is 0, and the witness program is 20 bytes: It is interpreted as a pay-to-witness-public-key-hash (P2WPKH) program.

            // BIP141: The witness must consist of exactly 2 items (≤ 520 bytes each). The first one a signature, and the second one a public key.
            // The `≤ 520` part is checked by ``Script.run()``.
            guard stack.count == 2 else {
                throw ScriptError.initialStackLimitExceeded
            }

            // For P2WPKH witness program, the scriptCode is 0x1976a914{20-byte-pubkey-hash}88ac.
            let witnessScript = BitcoinScript.segwitPKHScriptCode(witnessProgram)

            try context.run(witnessScript, stack: stack)

            // The verification must result in a single TRUE on the stack.
            guard context.stack.count == 1, let last = context.stack.last, ScriptBoolean(last).value else {
                throw ScriptError.falseReturned
            }
        } else if witnessProgram.count == SHA256.Digest.byteCount /* 32 */ {
            // If the version byte is 0, and the witness program is 32 bytes: It is interpreted as a pay-to-witness-script-hash (P2WSH) program.

            // BIP141: The witnessScript (≤ 10,000 bytes) is popped off the initial witness stack.
            guard let witnessScriptRaw = stack.popLast() else {
                preconditionFailure()
            }
            // This check is repeated inside ``Script.run()``.
            if witnessScriptRaw.count > BitcoinScript.maxScriptSize {
                throw ScriptError.scriptSizeLimitExceeded
            }

            // SHA256 of the witnessScript must match the 32-byte witness program.
            guard Data(SHA256.hash(data: witnessScriptRaw)) == witnessProgram else {
                throw ScriptError.wrongWitnessScriptHash
            }

            let witnessScript = BitcoinScript(witnessScriptRaw, sigVersion: .witnessV0)
            try context.run(witnessScript, stack: stack)

            // The script must not fail, and result in exactly a single TRUE on the stack.
            guard context.stack.count == 1, let last = context.stack.last, ScriptBoolean(last).value else {
                throw ScriptError.falseReturned
            }
        } else {
            // If the version byte is 0, but the witness program is neither 20 nor 32 bytes, the script must fail.
            throw ScriptError.witnessProgramWrongLength
        }
    }

    /// BIP341, BIP342
    private func verifyTaproot(_ context: inout ScriptContext, witnessVersion: Int, witnessProgram: Data) throws {
        let inputIndex = context.inputIndex
        let prevouts = context.prevouts
        let config = context.config

        guard let witness = inputs[inputIndex].witness else { preconditionFailure() }
        guard config.contains(.taproot) else { return }

        var stack = witness.elements
        // Fail if the witness stack has 0 elements.
        if stack.count == 0 { throw ScriptError.missingTaprootWitness }

        // In this case it is the key (aka taproot output key q)
        let outputKeyData = witnessProgram

        // this last element is called annex a and is removed from the witness stack
        if witness.taprootAnnex != .none { stack.removeLast() }

        // If there is exactly one element left in the witness stack, key path spending is used:
        if stack.count == 1 {
            guard let publicKey = PublicKey(xOnly: witnessProgram) else {
                fatalError()
            }
            let extendedSignature = try ExtendedSignature(schnorrData: stack[0])
            let sighash = self.signatureHashSchnorr(sighashType: extendedSignature.sighashType, inputIndex: inputIndex, prevouts: prevouts, tapscriptExtension: .none, sighashCache: &context.sighashCache)
            guard extendedSignature.signature.verify(messageHash: sighash, publicKey: publicKey) else {
                throw ScriptError.invalidSchnorrSignature
            }
            return
        }

        // If there are at least two witness elements left, script path spending is used:
        // The last stack element is called the control block c
        let control = stack.removeLast()

        // control block c, and must have length 33 + 32m, for a value of m that is an integer between 0 and 128, inclusive. Fail if it does not have such a length.
        guard control.count >= taprootControlBaseSize && (control.count - taprootControlBaseSize) % taprootControlNodeSize == 0 && (control.count - taprootControlBaseSize) / taprootControlNodeSize <= 128 else {
            throw ScriptError.invalidTapscriptControlBlock
        }

        // Call the second-to-last stack element s, the script.
        // The script as defined in BIP341 (i.e., the penultimate witness stack element after removing the optional annex) is called the tapscript
        let tapscriptData = stack.removeLast()

        // Let p = c[1:33] and let P = lift_x(int(p)) where lift_x and [:] are defined as in BIP340. Fail if this point is not on the curve.
        // q is referred to as taproot output key and p as taproot internal key.
        let internalKeyData = control.dropFirst().prefix(PublicKey.xOnlyLength)

        // Fail if this point is not on the curve.
        guard let internalKey = PublicKey(xOnly: internalKeyData), internalKey.isPointOnCurve(useXOnly: true) else { throw ScriptError.invalidTaprootPublicKey }

        // Let v = c[0] & 0xfe and call it the leaf version
        let leafVersion = control[0] & 0xfe

        // Let k0 = hashTapLeaf(v || compact_size(size of s) || s); also call it the tapleaf hash.
        let tapLeafHash = Data(SHA256.hash(data: [leafVersion] + tapscriptData.varLenData, tag: "TapLeaf"))

        // Compute the Merkle root from the leaf and the provided path.
        let merkleRoot = computeMerkleRoot(controlBlock: control, tapLeafHash: tapLeafHash)

        let tweak = internalKey.tapTweak(merkleRoot: merkleRoot)

        // Verify that the output pubkey matches the tweaked internal pubkey, after correcting for parity.
        //let parity = (control[0] & 0x01) != 0
        let hasEvenY = (control[0] & 0x01) == 0
        let outputKey = PublicKey(xOnly: outputKeyData, hasEvenY: hasEvenY)! // TODO: Check if this could fail somehow when witness data contains an invalid public key.
        guard internalKey.checkTweak(tweak, outputKey: outputKey) else {
            throw ScriptError.invalidTaprootTweak
        }

        // BIP 342 Tapscript - https://github.com/bitcoin/bips/blob/master/bip-0342.mediawiki
        // The leaf version is 0xc0 (i.e. the first byte of the last witness element after removing the optional annex is 0xc0 or 0xc1), marking it as a tapscript spend.
        guard leafVersion == 0xc0 else {
            if config.contains(.discourageUpgradableTaprootVersion) {
                throw ScriptError.disallowedTaprootVersion
            }
            return
        }

        let tapscript = BitcoinScript(tapscriptData, sigVersion: .witnessV1)
        try context.run(tapscript, stack: stack, leafVersion: leafVersion, tapLeafHash: tapLeafHash)
    }
}
