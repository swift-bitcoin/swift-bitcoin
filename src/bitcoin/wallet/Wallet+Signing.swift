import Foundation
import BitcoinCrypto

extension Wallet {

    public static func convertToWIF(secretKey: String, compressedPublicKey: Bool = true, network: WalletNetwork = .main) throws -> String {

        guard let secretKey = Data(hex: secretKey) else {
            throw WalletError.invalidHexString
        }

        return try convertToWIF(secretKey: secretKey, network: network)
    }

    public static func convertToWIF(secretKey: Data, compressedPublicKey: Bool = true, network: WalletNetwork = .main) throws -> String {
        var data = Data()
        data.appendBytes(UInt8(network.base58VersionPrivate))
        data.append(secretKey)
        if compressedPublicKey {
            data.appendBytes(UInt8(0x01))
        }
        return Base58.base58CheckEncode(data)
    }

    public static func wifToEC(secretKey: String) throws -> (secretKey: Data, compressedPublicKey: Bool) {

        guard var secretKeyData = Base58.base58CheckDecode(secretKey) else {
            throw WalletError.invalidSecretKeyEncoding
        }

        guard let versionByte = secretKeyData.popFirst(), versionByte == WalletNetwork.main.base58VersionPrivate || versionByte == WalletNetwork.test.base58VersionPrivate else {
            throw WalletError.invalidSecretKeyEncoding
        }

        let isPublicKeyCompressed: Bool
        if secretKeyData.count == 33, let last = secretKeyData.last {
            guard last == 0x01 else {
                throw WalletError.invalidSecretKeyEncoding
            }
            isPublicKeyCompressed = true
        } else {
            guard secretKeyData.count == 32 else {
                throw WalletError.invalidSecretKeyEncoding
            }
            isPublicKeyCompressed = false
        }

        let endIndex = isPublicKeyCompressed ? secretKeyData.endIndex.advanced(by: -1) : secretKeyData.endIndex
        let secretKey = secretKeyData[secretKeyData.startIndex ..< endIndex]

        guard checkSecretKey(secretKey) else {
            throw WalletError.invalidSecretKey
        }
        return (secretKey, isPublicKeyCompressed)
    }

    public static func sign(secretKey: String, message: String) throws -> String {

        let (secretKey, compressedPublicKey) = try wifToEC(secretKey: secretKey)

        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.invalidMessageEncoding
        }

        return try sign(secretKey: secretKey, message: messageData, compressedPublicKey: compressedPublicKey).base64EncodedString()
    }

    public static func sign(secretKey: Data, message: Data, compressedPublicKey: Bool) throws -> Data {
        signRecoverable(message: message, secretKey: secretKey, compressedPublicKey: compressedPublicKey)
    }

    public static func verify(address: String, signature: String, message: String) throws -> Bool {

        // Decode P2PKH address
        guard let addressData = Base58.base58CheckDecode(address),
              let first = addressData.first,
              first == WalletNetwork.main.base58Version || first == WalletNetwork.test.base58Version
        else {
            throw WalletError.invalidAddress
        }
        let publicKeyHash = addressData[addressData.startIndex.advanced(by: 1)...]

        guard let signature = signature.data(using: .utf8), let signature = Data(base64Encoded: signature) else {
            throw WalletError.invalidSignatureEncoding
        }

        guard let message = message.data(using: .utf8) else {
            throw WalletError.invalidMessageEncoding
        }

        return try verify(publicKeyHash: publicKeyHash, signature: signature, message: message)
    }

    public static func verify(publicKeyHash: Data, signature: Data, message: Data) throws -> Bool {
        guard let publicKey = recoverPublicKey(message: message, signature: signature) else {
            return false
        }
        return hash160(publicKey) == publicKeyHash
    }
}
