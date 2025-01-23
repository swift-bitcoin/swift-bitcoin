import Foundation
import BitcoinCrypto
import BitcoinBase

/// Witness version 0 Bitcoin address.
public struct SegwitAddress: BitcoinAddress {

    public init?(_ address: String) {
        walletLoop: for network in WalletNetwork.allCases {
            var version: Int
            var hash: Data
            do {
                (version, hash) = try SegwitAddressDecoder(hrp: network.bech32HRP).decode(address)
                self.network = network
                guard version == 0, (hash.count == Hash160.Digest.byteCount || hash.count == SHA256.Digest.byteCount) else {
                    return nil
                }
                self.hash = hash
                return
            } catch SegwitAddressDecoder.Error.hrpMismatch(_, _) {
                continue walletLoop
            } catch {
                break walletLoop
            }
        }
        return nil
    }

    public let network: WalletNetwork
    public let hash: Data

    public init(_ secretKey: SecretKey, network: WalletNetwork = .main) {
        self.init(secretKey.pubkey, network: network)
    }

    public init(_ pubkey: PubKey, network: WalletNetwork = .main) {
        self.network = network
        hash = Data(Hash160.hash(data: pubkey.data))
    }

    public init(_ script: BitcoinScript, network: WalletNetwork = .main) {
        self.network = network
        hash = Data(SHA256.hash(data: script.binaryData))
    }

    public var description: String {
        try! SegwitAddressEncoder(hrp: network.bech32HRP, version: 0).encode(hash)
    }

    public var script: BitcoinScript {
        if hash.count == RIPEMD160.Digest.byteCount {
            .payToWitnessPubkeyHash(hash)
        } else {
            .payToWitnessScriptHash(hash)
        }
    }

    public func out(_ value: SatoshiAmount) -> TxOut {
        .init(value: value, script: script)
    }
}
