import Foundation

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
