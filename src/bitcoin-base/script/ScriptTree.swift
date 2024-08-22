import Foundation
import BitcoinCrypto

public indirect enum ScriptTree: Equatable, Sendable {
    // Int is the leaf_version. Its value should be 0xc0 (or 0xc1) for BIP342.
    // Data is the script data.
    case leaf(Int, Data)
    case branch(Self, Self)

    public init(_ scripts: [Data], leafVersion v: Int) {
        // TODO: Implement tapscript for any number of script leafs
        precondition(!scripts.isEmpty && scripts.count <= 8)
        self = switch scripts.count {
        case 1:
            ScriptTree.leaf(v, scripts[0])
        case 2:
            ScriptTree.branch(
                .leaf(v, scripts[0]),
                .leaf(v, scripts[1]))
        case 3:
            ScriptTree.branch(
                .branch(
                    .leaf(v, scripts[0]),
                    .leaf(v, scripts[1])),
                .leaf(v, scripts[2]))
        case 4:
            ScriptTree.branch(
                .branch(
                    .leaf(v, scripts[0]),
                    .leaf(v, scripts[1])),
                .branch(
                    .leaf(v, scripts[2]),
                    .leaf(v, scripts[3])))
        case 5:
            ScriptTree.branch(
                .branch(
                    .branch(
                        .leaf(v, scripts[0]),
                        .leaf(v, scripts[1])),
                    .branch(
                        .leaf(v, scripts[2]),
                        .leaf(v, scripts[3]))),
                .leaf(v, scripts[4]))
        case 6:
            ScriptTree.branch(
                .branch(
                    .branch(
                        .leaf(v, scripts[0]),
                        .leaf(v, scripts[1])),
                    .branch(
                        .leaf(v, scripts[2]),
                        .leaf(v, scripts[3]))),
                .branch(
                    .leaf(v, scripts[4]),
                    .leaf(v, scripts[5])))
        case 7:
            ScriptTree.branch(
                .branch(
                    .branch(
                        .leaf(v, scripts[0]),
                        .leaf(v, scripts[1])),
                    .branch(
                        .leaf(v, scripts[2]),
                        .leaf(v, scripts[3]))),
                .branch(
                    .branch(
                        .leaf(v, scripts[4]),
                        .leaf(v, scripts[5])),
                    .leaf(v, scripts[6])))
        case 8:
            ScriptTree.branch(
                .branch(
                    .branch(
                        .leaf(v, scripts[0]),
                        .leaf(v, scripts[1])),
                    .branch(
                        .leaf(v, scripts[2]),
                        .leaf(v, scripts[3]))),
                .branch(
                    .branch(
                        .leaf(v, scripts[4]),
                        .leaf(v, scripts[5])),
                    .branch(
                        .leaf(v, scripts[6]),
                        .leaf(v, scripts[7]))))
        default:
            preconditionFailure()
        }
    }

    /// Calculates the merkle root as well as some additional tree info for generating control blocks.
    public func calcMerkleRoot() -> ([(ScriptTree, Data)], Data) {
        switch self {
        case .leaf(_, _):
            return ([(self, Data())], leafHash)
        case .branch(let scriptTreeLeft, let scriptTreeRight):
            let (left, leftHash) = scriptTreeLeft.calcMerkleRoot()
            let (right, rightHash) = scriptTreeRight.calcMerkleRoot()
            let ret = left.map { ($0, $1 + rightHash) } + right.map { ($0, $1 + leftHash) }
            let invertHashes = rightHash.hex < leftHash.hex
            let newLeftHash = invertHashes ? rightHash : leftHash
            let newRightHash = invertHashes ? leftHash : rightHash
            let branchHash = taggedHash(tag: "TapBranch", payload: newLeftHash + newRightHash)
            return (ret, branchHash)
        }
    }

    var leafs: [ScriptTree] {
        leafs()
    }

    private func leafs(_ partial: [ScriptTree] = []) -> [ScriptTree] {
        switch self {
        case .leaf(_, _):
            return partial + [self]
        case .branch(let left, let right):
            return left.leafs(partial) + right.leafs(partial)
        }
    }

    var leafHash: Data {
        guard case .leaf(let version, let scriptData) = self else {
            preconditionFailure("Needs to be a leaf.")
        }
        let leafVersionData = withUnsafeBytes(of: UInt8(version)) { Data($0) }
        return taggedHash(tag: "TapLeaf", payload: leafVersionData + scriptData.varLenData)
    }

    public func getOutputKey(secretKey: SecretKey) -> Data {
        let (_, merkleRoot) = calcMerkleRoot()
        let internalKey = PublicKey(secretKey, requireEvenY: true)
        let outputKey = internalKey.taprootOutputKey(merkleRoot: merkleRoot)
        return outputKey.xOnlyData.x
    }
}
