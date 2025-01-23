import Foundation
import BitcoinCrypto
import BitcoinBase

/// Witness version 1 or higher Bitcoin address.
public struct TaprootAddress: BitcoinAddress {

    public init?(_ address: String) {
        walletLoop: for network in WalletNetwork.allCases {
            var version: Int
            var program: Data
            do {
                (version, program) = try SegwitAddressDecoder(hrp: network.bech32HRP).decode(address)
                self.network = network
                guard version > 0, let outputKey = PubKey(xOnly: program) else {
                    return nil
                }
                self.outputKey = outputKey
                return
            } catch SegwitAddressDecoder.Error.hrpMismatch(_, _) {
                continue walletLoop
            } catch {
                break walletLoop
            }
        }
        return nil
    }

    public init(_ secretKey: SecretKey, scripts: [BitcoinScript] = [], network: WalletNetwork = .main) {
        self.init(secretKey.taprootInternalKey, scripts: scripts, network: network)
    }

    public init(_ internalKey: PubKey, scripts: [BitcoinScript] = [], network: WalletNetwork = .main) {
        precondition(scripts.count <= 8)
        precondition(internalKey.hasEvenY)
        self.network = network
        if scripts.isEmpty {
            outputKey = internalKey.taprootOutputKey().xOnlyNormalized!
            return
        }
        let scriptTree = ScriptTree(scripts.map(\.binaryData), leafVersion: 192)
        outputKey = internalKey.taprootOutputKey(scriptTree).xOnlyNormalized!
    }

    public let network: WalletNetwork
    public let outputKey: PubKey

    public var description: String {
        try! SegwitAddressEncoder(hrp: network.bech32HRP, version: 1).encode(outputKey.xOnlyData)
    }

    public var script: BitcoinScript {
        .payToTaproot(outputKey)
    }

    public func out(_ value: SatoshiAmount) -> TxOut {
        .init(value: value, script: script)
    }
}
