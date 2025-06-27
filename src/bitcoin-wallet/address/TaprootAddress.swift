import Foundation
import BitcoinCrypto
import BitcoinBase

/// Witness version 1 or higher Bitcoin address.
public struct TaprootAddress: AddressProtocol {

    public init?(_ address: String) {
        walletLoop: for network in WalletNetwork.allCases {
            var version: Int
            var program: Data
            do {
                (version, program) = try SegwitAddressDecoder(hrp: network.bech32HRP).decode(address)
                self.network = network
                guard version > 0, let outputKey = PublicKey(xOnly: program) else {
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

    public init(_ secretKey: SecretKey, scripts: [Script] = [], network: WalletNetwork = .mainnet) {
        self.init(secretKey.taprootInternalKey, scripts: scripts, network: network)
    }

    public init(_ internalKey: PublicKey, scripts: [Script] = [], network: WalletNetwork = .mainnet) {
        precondition(scripts.count <= 8)
        precondition(internalKey.hasEvenY)
        self.network = network
        if scripts.isEmpty {
            outputKey = internalKey.taprootOutputKey().xOnlyNormalized!
            return
        }
        let scriptTree = TapscriptTree(scripts.map(\.data), leafVersion: 192)
        outputKey = internalKey.taprootOutputKey(scriptTree).xOnlyNormalized!
    }

    public let network: WalletNetwork
    public let outputKey: PublicKey

    public var description: String {
        try! SegwitAddressEncoder(hrp: network.bech32HRP, version: 1).encode(outputKey.xOnlyData)
    }

    public var script: Script {
        .payToTaproot(outputKey)
    }
}
