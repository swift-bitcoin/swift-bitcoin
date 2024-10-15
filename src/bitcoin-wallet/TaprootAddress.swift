import Foundation
import BitcoinCrypto
import BitcoinBase

public struct TaprootAddress: CustomStringConvertible, Equatable, Sendable {

    public let network: WalletNetwork
    public let outputKey: PublicKey

    public init(_ secretKey: SecretKey, scripts: [BitcoinScript] = [], network: WalletNetwork = .main) {
        self.init(secretKey.taprootInternalKey, scripts: scripts, network: network)
    }

    public init(_ internalKey: PublicKey, scripts: [BitcoinScript] = [], network: WalletNetwork = .main) {
        precondition(scripts.count <= 8)
        precondition(internalKey.hasEvenY)
        self.network = network
        if scripts.isEmpty {
            outputKey = internalKey.taprootOutputKey()
            return
        }
        let scriptTree = ScriptTree(scripts.map(\.data), leafVersion: 192)
        outputKey = internalKey.taprootOutputKey(scriptTree)
    }

    public var description: String {
        try! SegwitAddressEncoder(hrp: network.bech32HRP, version: 1).encode(outputKey.xOnlyData)
    }

    public var script: BitcoinScript {
        .payToTaproot(outputKey)
    }

    public func output(_ value: BitcoinAmount) -> TransactionOutput {
        .init(value: value, script: script)
    }
}
