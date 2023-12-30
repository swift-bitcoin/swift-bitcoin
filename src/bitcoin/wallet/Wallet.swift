import Foundation

/// Namespase for common wallet operations. From seed to derivation paths.
public enum Wallet { }

extension Wallet {
    
    /// Generates a new secret key suitable for ECDSA signing.
    /// - Returns: The secret key in hex format.
    public static func createSecretKey() -> String {
        Bitcoin.createSecretKey().hex
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
        Bitcoin.getPublicKey(secretKey: secretKey, compress: true)
    }

    /// Creates an address from the provided public key.
    /// - Parameters:
    ///   - publicKey: A valid DER-encoded compressed/uncompressed public key in hex format.
    ///   - network: The network for which the produced address will be valid.
    /// - Returns: The generated address in hex format.
    public static func getAddress(publicKey: String, network: WalletNetwork) throws -> String {
        guard let publicKey = Data(hex: publicKey) else {
            throw WalletError.invalidHexString
        }
        return try getAddress(publicKey: publicKey, network: network)
    }

    public static func getAddress(publicKey: Data, network: WalletNetwork = .main) throws -> String {
        do {
            try checkPublicKeyEncoding(publicKey)
        } catch {
            throw WalletError.invalidPublicKey
        }
        var data = Data()
        data.addBytes(of: UInt8(network.base58Version))
        data.append(hash160(publicKey))
        return Base58.base58CheckEncode(data)
    }
}
