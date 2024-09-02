import Foundation
import BitcoinCrypto
import BitcoinBase

public struct TaprootAddress: CustomStringConvertible {

    public let network: WalletNetwork
    public let outputKey: PublicKey

    public init(_ publicKey: PublicKey, scripts: [BitcoinScript] = [], network: WalletNetwork = .main) {
        precondition(scripts.count <= 8)
        precondition(scripts.allSatisfy { $0.sigVersion == .witnessV1})
        self.network = network
        if scripts.isEmpty {
            outputKey = publicKey.taprootOutputKey()
            return
        }
        let scriptTree = ScriptTree(scripts.map(\.data), leafVersion: 192)
        let (_, merkleRoot) = scriptTree.calcMerkleRoot()
        outputKey = publicKey.taprootOutputKey(merkleRoot: merkleRoot)
    }

    public var description: String {
        try! SegwitAddressEncoder(hrp: network.bech32HRP, version: 1).encode(outputKey.xOnlyData)
    }
}
