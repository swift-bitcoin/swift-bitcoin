import Foundation
import BitcoinCrypto
import BitcoinBase

extension Wallet {

    /// BIP13
    public static func getAddress(scripts: [String], publicKey: String?, sigVersion: SigVersion, network: WalletNetwork) throws -> String {

        let publicKey = if let publicKey {
            if let publicKey = Data(hex: publicKey) {
                publicKey
            } else {
                throw WalletError.invalidHexString
            }
        }  else {
            if sigVersion != .witnessV1 {
                Data?.none
            } else {
                throw WalletError.publicKeyRequired
            }
        }

        let scriptsAsData = scripts.compactMap { Data(hex: $0) }
        guard scriptsAsData.count == scripts.count else {
            throw WalletError.invalidHexString
        }
        return try getAddress(scripts: scriptsAsData, publicKey: publicKey, sigVersion: sigVersion, network: network)
    }

    /// Decodes a script into its assembly textual representation.
    ///
    /// Part of BIP13.
    public static func getAddress(scripts: [Data], publicKey: Data?, sigVersion: SigVersion = .base, network: WalletNetwork = .main) throws -> String {
        precondition( (sigVersion != .witnessV1 && publicKey == .none) || (sigVersion == .witnessV1 && publicKey != .none))
        switch sigVersion {
        case .base:
            var data = Data()
            data.appendBytes(UInt8(network.base58VersionScript))
            data.append(hash160(scripts[0]))
            return Base58.base58CheckEncode(data)
        case .witnessV0:
            return try SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 0, program: sha256(scripts[0]))
        case .witnessV1:
            guard let publicKey else { preconditionFailure() }
            if scripts.count > 8 {
                throw WalletError.tooManyTapscriptLeaves
            }
            let scriptTree = ScriptTree(scripts, leafVersion: 192)
            let (_, merkleRoot) = scriptTree.calcMerkleRoot()
            let internalKey = publicKeyToXOnly(publicKey)
            let outputKey = getOutputKey(internalKey: internalKey, merkleRoot: merkleRoot)
            return try SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 1, program: outputKey)
        }
    }

    /// Decodes a script into its assembly textual representation.
    /// - Parameters:
    ///   - script: The script in hex format.
    ///   - sigVersion: The signature version.
    /// - Returns: The script's assembly code.
    public static func decodeScript(script: String, sigVersion: SigVersion) throws -> String {
        guard let script = Data(hex: script) else {
            throw WalletError.invalidHexString
        }
        return decodeScript(script, sigVersion: sigVersion)
    }

    /// Decodes script data into its assembly textual representation.
    /// - Parameters:
    ///   - script: The script's data.
    ///   - sigVersion: The signature version.
    /// - Returns: The script's assembly code.
    public static func decodeScript(_ scriptData: Data, sigVersion: SigVersion = .base) -> String {
        let script = BitcoinScript(scriptData, sigVersion: sigVersion)
        return script.asm
    }
}
