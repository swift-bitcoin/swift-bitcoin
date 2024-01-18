import Foundation
import BitcoinCrypto

extension Wallet {

    /// Creates a random seed (entropy) for HD wallets.
    /// - Parameter bytes: The length of the seed to generate.
    /// - Returns: The generated seed serialized as hexadecimal.
    public static func generateSeed(bytes: Int = 32) -> String {
        getRandBytes(bytes).hex
    }

    /// Creates the extended master private key for a hierarchical deterministic wallet using the provided seed.
    /// - Parameter seedHex: The seed in hex format.
    /// - Returns: The serialized extended master private key.
    public static func computeHDMasterKey(_ seedHex: String) throws -> String {
        guard let seed = Data(hex: seedHex) else {
            throw WalletError.invalidHexString
        }
        precondition(seed.count >= 16 && seed.count <= 64)
        let result = hmacSHA512("Bitcoin seed", data: seed)
        let key = result[...result.startIndex.advanced(by: 31)]
        let chaincode = result[result.startIndex.advanced(by: 32)...]
        let hdKey = HDExtendedKey(isPrivate: true, key: key, chaincode: chaincode, fingerprint: 0, depth: 0, keyIndex: 0)
        return hdKey.serialized
    }

    /// Derives a new private/public key from a parent extended private/public key.
    /// - Parameters:
    ///   - isPrivate: Whether the provided key should be interpreted as a private or a public key. This is checked against the value obtained from deserializing the provided key.
    ///   - keyHex: The parent extended private/public key.
    ///   - index: The child index to derive.
    ///   - harden: Whether to apply hardened derivation (only for private keys).
    /// - Returns: The newly derived child extended private/public key.
    public static func deriveHDKey(isPrivate: Bool = true, key keyHex: String, index: Int, harden: Bool = false) throws -> String {
        guard let hdKey = HDExtendedKey(keyHex) else {
            throw WalletError.invalidExtendedKey
        }
        if isPrivate && !hdKey.isPrivate || (!isPrivate && hdKey.isPrivate) {
            throw WalletError.invalidExtendedKeyType
        }
        if !isPrivate && harden {
            throw WalletError.attemptToDeriveHardenedPublicKey
        }
        return hdKey.derive(child: index, harden: harden).serialized
    }

    /// Turns an extended private key into public one.
    /// - Parameter keyHex: The extended private key to neuter.
    /// - Returns: The corresponding extended public key.
    public static func neuterHDPrivateKey(key keyHex: String) throws -> String {
        guard let hdKey = HDExtendedKey(keyHex) else {
            throw WalletError.invalidExtendedKey
        }
        return (hdKey.isPrivate ? hdKey.neutered : hdKey).serialized
    }
}
