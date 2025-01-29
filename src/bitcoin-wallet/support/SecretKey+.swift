import Foundation
import BitcoinCrypto

public extension SecretKey {

    struct WIFMetadata {
        public let isMainnet: Bool
        public let compressedPubkeys: Bool
    }

    init?(wif: String) {
        var metadata = WIFMetadata?.none
        self.init(wif: wif, metadata: &metadata)
    }

    init?(wif: String, metadata: inout WIFMetadata?) {
        precondition(metadata == nil)

        guard var secretKeyData = Base58Decoder().decode(wif) else {
            // TODO: throw WalletError.invalidSecretKeyEncoding
            return nil
        }

        guard let versionByte = secretKeyData.popFirst(), versionByte == Self.base58VersionMain || versionByte == Self.base58VersionTest else {
            // throw invalidBase58VersionByte
            return nil
        }
        let isMainnet = versionByte == Self.base58VersionMain

        let compressedPubkeys: Bool
        if secretKeyData.count == PubKey.compressedLength, let last = secretKeyData.popLast() {
            guard last == 0x01 else {
                // throw WalletError.invalidSecretKeyEncoding
                return nil
            }
            compressedPubkeys = true
        } else {
            guard secretKeyData.count == SecretKey.keyLength else {
                // throw WalletError.invalidSecretKeyEncoding
                return nil
            }
            compressedPubkeys = false
        }
        metadata = .init(isMainnet: isMainnet, compressedPubkeys: compressedPubkeys)
        self.init(secretKeyData)
    }

    func toWIF(compressedPubkeys: Bool = true, mainnet: Bool = true) -> String {
        var data = Data()
        data.append(Data([mainnet ? Self.base58VersionMain : Self.base58VersionTest]))
        data.append(self.data)
        if compressedPubkeys {
            data.append(Data([0x01]))
        }
        return Base58Encoder().encode(data)
    }

    /// For use when WIF encoding/decoding secret keys.
    private static let base58VersionMain = UInt8(0x80) // 128, mainnet
    private static let base58VersionTest = UInt8(0xef) // 239, testnet, regtest
}
