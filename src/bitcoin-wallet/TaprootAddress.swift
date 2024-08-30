import Foundation
import BitcoinCrypto

public struct TaprootAddress: CustomStringConvertible {

    public let network: WalletNetwork
    public let outputKey: PublicKey

    public init(_ publicKey: PublicKey, network: WalletNetwork = .main) {
        self.network = network
        outputKey = publicKey.taprootOutputKey()
    }

    public var description: String {
        try! SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 1, program: outputKey.xOnlyData.x)
    }
}
