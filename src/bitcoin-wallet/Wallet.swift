import Foundation
import BitcoinCrypto
import BitcoinBase

/// Namespase for common wallet operations. From seed to derivation paths.
public enum Wallet { }

extension Wallet {
    
    /// Generates a new secret key suitable for ECDSA signing.
    /// - Returns: The secret key in hex format.
    public static func createSecretKey() -> String {
        createSecretKey().hex
    }
    
    /// Generates a new secret key suitable for ECDSA signing.
    /// - Returns: The secret key in hex format.
    public static func createSecretKey() -> Data {
        SecretKey().data
    }
    
    /// Computes the public key corresponding to the provided secret key.
    /// - Parameter secretKeyHex: The secret key in hex format.
    /// - Returns: The public key in hex format.
    public static func getPublicKey(secretKeyHex: String) throws -> String {
        guard let secretKeyData = Data(hex: secretKeyHex) else {
            throw WalletError.invalidHexString
        }
        guard let secretKey = SecretKey(secretKeyData) else {
            throw WalletError.invalidSecretKey
        }
        return PublicKey(secretKey).data.hex
    }

    /// Creates an address from the provided public key.
    /// - Parameters:
    ///   - publicKeyHex: A valid DER-encoded compressed/uncompressed public key in hex format.
    ///   - sigVersion: The signature version which  determines the address type.
    ///   - network: The network for which the produced address will be valid.
    /// - Returns: The generated address in hex format.
    public static func getAddress(publicKeyHex: String, sigVersion: SigVersion, network: WalletNetwork) throws -> String {
        guard let publicKeyData = Data(hex: publicKeyHex) else {
            throw WalletError.invalidHexString
        }
        guard let publicKey = PublicKey(publicKeyData) else {
            throw WalletError.invalidPublicKey
        }
        return try getAddress(publicKey: publicKey, sigVersion: sigVersion, network: network)
    }

    public static func getAddress(publicKey: PublicKey, sigVersion: SigVersion = .base, network: WalletNetwork = .main) throws -> String {
        switch sigVersion {
        case .base:
            var data = Data()
            data.appendBytes(UInt8(network.base58Version))
            data.append(hash160(publicKey.data))
            return Base58Encoder().encode(data)
        case .witnessV0:
            return try SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 0, program: hash160(publicKey.data))
        case .witnessV1:
            let outputKey = publicKey.taprootOutputKey()
            let outputKeyData = outputKey.xOnlyData.x
            return try SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 1, program: outputKeyData)
        }
    }
}
