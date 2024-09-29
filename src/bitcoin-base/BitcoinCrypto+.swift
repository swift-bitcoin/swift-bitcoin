import Foundation
import BitcoinCrypto

/// Extensions for BIP341 taproot.
extension SecretKey {

    public var taprootInternalKey: PublicKey {
        PublicKey(self, requireEvenY: true)
    }

    public func taprootSecretKey(_ scriptTree: ScriptTree? = .none) -> Self {
        let merkleRoot = if let scriptTree { scriptTree.calcMerkleRoot().1 } else { Data() }
        let tweak = taprootInternalKey.tapTweak(merkleRoot: merkleRoot)
        return tweakXOnly(tweak)
    }
}

/// Extensions for BIP341 taproot.
extension PublicKey {

    /// Self is an x-only internal public key.
    func tapTweak(merkleRoot: Data) -> Data {
        precondition(hasEvenY)
        return Data(SHA256.hash(data: xOnlyData + merkleRoot, tag: "TapTweak"))
    }

    /// Used in BitcoinWallet/TaprootAddress.
    package func taprootOutputKey(_ scriptTree: ScriptTree? = .none) -> PublicKey {
        let merkleRoot = if let scriptTree { scriptTree.calcMerkleRoot().1 } else { Data() }
        return taprootOutputKey(merkleRoot: merkleRoot)
    }

    /// Used in BIP341 tests as well as internally.
    package func taprootOutputKey(merkleRoot: Data) -> PublicKey {
        return tweakXOnly(tapTweak(merkleRoot: merkleRoot))
    }

    /// Used exclusively  in `BIP341Tests`.
    /// Self is an x-only public key.
    public func computeControlBlocks(_ givenScriptTree: ScriptTree?) -> (merkleRoot: Data, leafHashes: [Data], controlBlocks: [Data]) {
        precondition(hasEvenY)
        guard let givenScriptTree else {
            return (.init(), [], [])
        }
        let (treeInfo, merkleRoot) = givenScriptTree.calcMerkleRoot()
        let leafHashes = treeInfo.map {
            let (leaf, _) = $0
            return leaf.leafHash
        }
        let controlBlocks = treeInfo.map { leafInfo in
            let (scriptLeaf, path) = leafInfo
            guard case .leaf(let leafVersion, _) = scriptLeaf else { fatalError() }
            return computeControlBlock(merkleRoot: merkleRoot, leafVersion: leafVersion, path: path)
        }
        return (merkleRoot, leafHashes, controlBlocks)
    }

    /// Self is an x-only public key.
    private func computeControlBlock(merkleRoot: Data, leafVersion: Int, path: Data) -> Data {
        let outputKey = taprootOutputKey(merkleRoot: merkleRoot)
        let outputKeyYParityBit = UInt8(outputKey.hasEvenY ? 0 : 1)
        let controlByte = withUnsafeBytes(of: UInt8(leafVersion) + outputKeyYParityBit) { Data($0) }
        return controlByte + xOnlyData + path
    }
}

extension Signature {
    /// Standard Schnorr signature extended with the sighash type byte.
    public static let schnorrSignatureExtendedLength = 65
}
