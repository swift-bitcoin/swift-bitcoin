import Foundation

/// Checks that the public key is either compressed or uncompressed but always has a valid encoding.
func checkPublicKeyEncoding(_ publicKey: Data) throws {
    let keySize = 65
    let compressedKeySize = 33

    // Non-canonical public key: too short
    if publicKey.count < compressedKeySize { throw ScriptError.invalidPublicKeyEncoding }

    if publicKey[0] == 0x04 {
        // Non-canonical public key: invalid length for uncompressed key
        if publicKey.count != keySize { throw ScriptError.invalidPublicKeyEncoding }
    } else if (publicKey[0] == 0x02 || publicKey[0] == 0x03) {
        // Non-canonical public key: invalid length for compressed key
        if publicKey.count != compressedKeySize { throw ScriptError.invalidPublicKeyEncoding }
    } else {
        // Non-canonical public key: neither compressed nor uncompressed
        throw ScriptError.invalidPublicKeyEncoding
    }
}
