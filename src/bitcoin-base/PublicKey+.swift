import Foundation
import BitcoinCrypto

/// Extensions for BIP341 taproot.
extension PublicKey {

    /// Self is an x-only internal public key.
    func tapTweak(merkleRoot: Data) -> Data {
        // TODO: Reactivate pre-condition and fix creation of x-only public key from private key by forcing an even Y
        // precondition(hasEvenY)
        return Data(SHA256.hash(data: xOnlyData + merkleRoot, tag: "TapTweak"))
    }

    /// Used in BitcoinWallet/TaprootAddress as well as internally.
    package func taprootOutputKey(merkleRoot: Data = .init()) -> PublicKey {
        tweakXOnly(tapTweak(merkleRoot: merkleRoot))
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
