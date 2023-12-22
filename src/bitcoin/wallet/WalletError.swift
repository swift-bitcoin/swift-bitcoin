import Foundation

/// Errors during a wallet operation.
public enum WalletError: Error {

    /// The string contains a malformed hexadecimal representation.
    case invalidHexString

    /// The extended key could not be decoded.
    case invalidExtendedKey

    /// The key either must be public or private depending on the case.
    case invalidExtendedKeyType

    /// Hardened derivation cannot be applied to public keys.
    case attemptToDeriveHardenedPublicKey
}
