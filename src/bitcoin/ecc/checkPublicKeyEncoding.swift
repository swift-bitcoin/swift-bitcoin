import Foundation

/// Checks that the public key is either compressed or uncompressed but always has a valid encoding.
func checkPublicKeyEncoding(_ publicKey: Data) throws {
    let keySize = 65
    let compressedKeySize = 33

    // Non-canonical public key: too short
    if publicKey.count < compressedKeySize { throw ScriptError.invalidPublicKeyEncoding }

    guard let firstByte = publicKey.first else { preconditionFailure() }
    if firstByte == 0x04 {
        // Non-canonical public key: invalid length for uncompressed key
        if publicKey.count != keySize { throw ScriptError.invalidPublicKeyEncoding }
    } else if firstByte == 0x02 || firstByte == 0x03 {
        // Non-canonical public key: invalid length for compressed key
        if publicKey.count != compressedKeySize { throw ScriptError.invalidPublicKeyEncoding }
    } else {
        // Non-canonical public key: neither compressed nor uncompressed
        throw ScriptError.invalidPublicKeyEncoding
    }
}

/// BIP143: Checks that the public key is  compressed.
func checkCompressedPublicKeyEncoding(_ publicKey: Data) throws {
    let compressedKeySize = 33

    if publicKey.count != compressedKeySize {
        //  Non-canonical public key: invalid length for compressed key
        throw ScriptError.invalidPublicKeyEncoding
    }

    guard let firstByte = publicKey.first else { preconditionFailure() }
    if firstByte != 0x02 && firstByte != 0x03 {
        // Non-canonical public key: invalid prefix for compressed key
        throw ScriptError.invalidPublicKeyEncoding
    }
}
