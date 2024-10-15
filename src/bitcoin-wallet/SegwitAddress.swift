import Foundation
import BitcoinCrypto
import BitcoinBase

public struct SegwitAddress: CustomStringConvertible, Equatable, Sendable {

    public let network: WalletNetwork
    public let hash: Data

    public init(_ secretKey: SecretKey, network: WalletNetwork = .main) {
        self.init(secretKey.publicKey, network: network)
    }

    public init(_ publicKey: PublicKey, network: WalletNetwork = .main) {
        self.network = network
        hash = Data(Hash160.hash(data: publicKey.data))
    }

    public init(_ script: BitcoinScript, network: WalletNetwork = .main) {
        self.network = network
        hash = Data(SHA256.hash(data: script.data))
    }

    public var description: String {
        try! SegwitAddressEncoder(hrp: network.bech32HRP, version: 0).encode(hash)
    }

    public var script: BitcoinScript {
        if hash.count == RIPEMD160.Digest.byteCount {
            .payToWitnessPublicKeyHash(hash)
        } else {
            .payToWitnessScriptHash(hash)
        }
    }

    public func output(_ value: BitcoinAmount) -> TransactionOutput {
        .init(value: value, script: script)
    }
}
