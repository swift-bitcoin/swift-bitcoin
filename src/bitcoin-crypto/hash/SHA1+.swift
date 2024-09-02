import Foundation
import Crypto

/// Insecure hash function still available as a SCRIPT operation code in Bitcoin.
public typealias SHA1 = Insecure.SHA1

/// Includes support for tagged hashes as introduced by BIP340.
public typealias SHA256 = Crypto.SHA256

/// Used indirectly by BIP32 and BIP39 implementations.
public typealias SHA512 = Crypto.SHA512

/// A hash-based message authentication algorithm used by BIP32 key derivation in Hierarchically Deterministic (HD) wallets.
public typealias HMAC = Crypto.HMAC
