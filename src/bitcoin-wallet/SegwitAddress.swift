import Foundation
import BitcoinCrypto

public struct SegwitAddress: CustomStringConvertible {

    public let network: WalletNetwork
    public let publicKeyHash: Data

    public init(_ publicKey: PublicKey, network: WalletNetwork = .main) {
        self.network = network
        publicKeyHash = hash160(publicKey.data)
    }

    public var description: String {
        try! SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 0, program: publicKeyHash)
    }
}
