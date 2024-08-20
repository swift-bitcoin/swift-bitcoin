import Foundation
import BitcoinCrypto

extension Wallet {

    public static func convertToWIF(secretKeyHex: String, compressedPublicKeys: Bool = true, network: WalletNetwork = .main) throws -> String {
        guard let secretKeyData = Data(hex: secretKeyHex) else {
            throw WalletError.invalidHexString
        }
        guard let secretKey = SecretKey(secretKeyData) else {
            throw WalletError.invalidSecretKey
        }
        return try convertToWIF(secretKey: secretKey, compressedPublicKeys: compressedPublicKeys, network: network)
    }

    public static func convertToWIF(secretKey: SecretKey, compressedPublicKeys: Bool = true, network: WalletNetwork = .main) throws -> String {
        var data = Data()
        data.appendBytes(UInt8(network.base58VersionPrivate))
        data.append(secretKey.data)
        if compressedPublicKeys {
            data.appendBytes(UInt8(0x01))
        }
        return Base58.base58CheckEncode(data)
    }

    public static func wifToEC(secretKeyWIF: String) throws -> (secretKey: SecretKey, compressedPublicKeys: Bool) {

        guard var secretKeyData = Base58.base58CheckDecode(secretKeyWIF) else {
            throw WalletError.invalidSecretKeyEncoding
        }

        guard let versionByte = secretKeyData.popFirst(), versionByte == WalletNetwork.main.base58VersionPrivate || versionByte == WalletNetwork.test.base58VersionPrivate else {
            throw WalletError.invalidSecretKeyEncoding
        }

        let compressedPublicKeys: Bool
        if secretKeyData.count == PublicKey.compressedLength, let last = secretKeyData.popLast() {
            guard last == 0x01 else {
                throw WalletError.invalidSecretKeyEncoding
            }
            compressedPublicKeys = true
        } else {
            guard secretKeyData.count == SecretKey.keyLength else {
                throw WalletError.invalidSecretKeyEncoding
            }
            compressedPublicKeys = false
        }

        guard let secretKey = SecretKey(secretKeyData) else {
            throw WalletError.invalidSecretKey
        }
        return (secretKey, compressedPublicKeys)
    }

    public static func sign(secretKeyWIF: String, message: String) throws -> String {

        let (secretKey, compressedPublicKeys) = try wifToEC(secretKeyWIF: secretKeyWIF)

        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.invalidMessageEncoding
        }

        return try sign(secretKey: secretKey, message: messageData, compressedPublicKeys: compressedPublicKeys).base64EncodedString()
    }

    public static func sign(secretKey: SecretKey, message: Data, compressedPublicKeys: Bool) throws -> Data {
        signRecoverable(message: message, secretKey: secretKey, compressedPublicKeys: compressedPublicKeys)
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
