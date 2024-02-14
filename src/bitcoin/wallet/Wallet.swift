import Foundation
import BitcoinCrypto

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
        BitcoinCrypto.createSecretKey()
    }
    
    /// Computes the public key corresponding to the provided secret key.
    /// - Parameter secretKey: The secret key in hex format.
    /// - Returns: The public key in hex format.
    public static func getPublicKey(secretKey: String) throws -> String {
        guard let secretKey = Data(hex: secretKey) else {
            throw WalletError.invalidHexString
        }
        return getPublicKey(secretKey: secretKey).hex
    }

    /// Computes the public key corresponding to the provided secret key.
    /// - Parameter secretKey: The secret key data.
    /// - Returns: The public key in hex format.
    public static func getPublicKey(secretKey: Data) -> Data {
        BitcoinCrypto.getPublicKey(secretKey: secretKey, compress: true)
    }

    /// Creates an address from the provided public key.
    /// - Parameters:
    ///   - publicKey: A valid DER-encoded compressed/uncompressed public key in hex format.
    ///   - sigVersion: The signature version which  determines the address type.
    ///   - network: The network for which the produced address will be valid.
    /// - Returns: The generated address in hex format.
    public static func getAddress(publicKey: String, sigVersion: SigVersion, network: WalletNetwork) throws -> String {
        guard let publicKey = Data(hex: publicKey) else {
            throw WalletError.invalidHexString
        }
        return try getAddress(publicKey: publicKey, sigVersion: sigVersion, network: network)
    }

    public static func getAddress(publicKey: Data, sigVersion: SigVersion = .base, network: WalletNetwork = .main) throws -> String {
        guard checkPublicKeyEncoding(publicKey) else {
            throw WalletError.invalidPublicKey
        }
        switch sigVersion {
        case .base:
            var data = Data()
            data.appendBytes(UInt8(network.base58Version))
            data.append(hash160(publicKey))
            return Base58.base58CheckEncode(data)
        case .witnessV0:
            return try SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 0, program: hash160(publicKey))
        case .witnessV1:
            let internalKey = getInternalKey(publicKey: publicKey)
            let outputKey = getOutputKey(internalKey: internalKey)
            return try SegwitAddrCoder.encode(hrp: network.bech32HRP, version: 1, program: outputKey)
        }
    }
}
