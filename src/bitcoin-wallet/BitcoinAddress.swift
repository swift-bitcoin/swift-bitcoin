import Foundation
import BitcoinCrypto

public struct BitcoinAddress: CustomStringConvertible {

    // TODO: BitcoinAddress networks are main or test. We can't use WalletNetwork here.
    public let network: WalletNetwork
    public let publicKeyHash: Data

    public init(_ publicKey: PublicKey, network: WalletNetwork = .main) {
        self.network = network
        publicKeyHash = hash160(publicKey.data)
    }

    public init?(_ address: String) {
        // Decode P2PKH address
        guard let data = Base58Decoder().decode(address),
              let versionByte = data.first,
              versionByte == WalletNetwork.main.base58Version || versionByte == WalletNetwork.test.base58Version
        else { return nil }
        network = versionByte == WalletNetwork.main.base58Version ? .main : .test
        publicKeyHash = data.dropFirst()
    }

    public var description: String {
        var data = Data()
        data.appendBytes(UInt8(network.base58Version))
        data.append(publicKeyHash)
        return Base58Encoder().encode(data)
    }
}
