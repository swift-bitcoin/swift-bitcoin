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

    /// Mnemonic word list language not supported.
    case languageNotSupported

    case invalidMnemonicOrPassphraseEncoding

    /// Mnemonic contains an invalid word.
    case mnemonicWordNotOnList

    /// Mnemonic phrase needs to contain a valid number of words.
    case mnemonicInvalidLength

    /// Checksum calculated for nmemonic phrase does not match.
    case invalidMnemonicChecksum
}
