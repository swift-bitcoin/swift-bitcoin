import Foundation

/// Checks that the public key is either compressed or uncompressed but always has a valid encoding.
public func checkPublicKeyEncoding(_ publicKey: Data) -> Bool {

    // Non-canonical public key: too short
    if publicKey.count < compressedPublicKeySize { return false }

    guard let firstByte = publicKey.first else { preconditionFailure() }
    if firstByte == 0x04 {
        // Non-canonical public key: invalid length for uncompressed key
        if publicKey.count != uncompressedPublicKeySize { return false }
    } else if firstByte == 0x02 || firstByte == 0x03 {
        // Non-canonical public key: invalid length for compressed key
        if publicKey.count != compressedPublicKeySize { return false }
    } else {
        // Non-canonical public key: neither compressed nor uncompressed
        return false
    }
    return true
}
