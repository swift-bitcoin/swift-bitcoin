import Foundation

/**
 * A canonical signature exists of: <30> <total len> <02> <len R> <R> <02> <len S> <S> <hashtype>
 * Where R and S are not negative (their first byte has its highest bit not set), and not
 * excessively padded (do not start with a 0 byte, unless an otherwise negative number follows,
 * in which case a single 0 byte is necessary and even required).
 *
 * See https://bitcointalk.org/index.php?topic=8392.msg127623#msg127623
 *
 * This function is consensus-critical since BIP66.
 */
func checkSignatureEncoding(_ sig: Data) throws {
    // Format: 0x30 [total-length] 0x02 [R-length] [R] 0x02 [S-length] [S] [sighash]
    // * total-length: 1-byte length descriptor of everything that follows,
    //   excluding the sighash byte.
    // * R-length: 1-byte length descriptor of the R value that follows.
    // * R: arbitrary-length big-endian encoded R value. It must use the shortest
    //   possible encoding for a positive integer (which means no null bytes at
    //   the start, except a single one when the next byte has its highest bit set).
    // * S-length: 1-byte length descriptor of the S value that follows.
    // * S: arbitrary-length big-endian encoded S value. The same rules apply.
    // * sighash: 1-byte value indicating what data is hashed (not part of the DER
    //   signature)

    // Minimum and maximum size constraints.
    if sig.count < 9 { throw ScriptError.invalidSignatureEncoding }
    if sig.count > 73{ throw ScriptError.invalidSignatureEncoding }

    // A signature is of type 0x30 (compound).
    if sig[0] != 0x30{ throw ScriptError.invalidSignatureEncoding }

    // Make sure the length covers the entire signature.
    if sig[1] != sig.count - 3{ throw ScriptError.invalidSignatureEncoding }

    // Extract the length of the R element.
    let lenR = Int(sig[3])

    // Make sure the length of the S element is still inside the signature.
    if 5 + lenR >= sig.count{ throw ScriptError.invalidSignatureEncoding }

    // Extract the length of the S element.
    let lenS = Int(sig[5 + lenR])

    // Verify that the length of the signature matches the sum of the length
    // of the elements.
    if lenR + lenS + 7 != sig.count { throw ScriptError.invalidSignatureEncoding }

    // Check whether the R element is an integer.
    if sig[2] != 0x02{ throw ScriptError.invalidSignatureEncoding }

    // Zero-length integers are not allowed for R.
    if lenR == 0 { throw ScriptError.invalidSignatureEncoding }

    // Negative numbers are not allowed for R.
    if sig[4] & 0x80 != 0 { throw ScriptError.invalidSignatureEncoding }

    // Null bytes at the start of R are not allowed, unless R would
    // otherwise be interpreted as a negative number.
    if lenR > 1 && sig[4] == 0x00 && sig[5] & 0x80 == 0 { throw ScriptError.invalidSignatureEncoding }

    // Check whether the S element is an integer.
    if sig[lenR + 4] != 0x02 { throw ScriptError.invalidSignatureEncoding }

    // Zero-length integers are not allowed for S.
    if lenS == 0 { throw ScriptError.invalidSignatureEncoding }

    // Negative numbers are not allowed for S.
    if sig[lenR + 6] & 0x80 != 0 { throw ScriptError.invalidSignatureEncoding }

    // Null bytes at the start of S are not allowed, unless S would otherwise be
    // interpreted as a negative number.
    if lenS > 1 && sig[lenR + 6] == 0x00 && sig[lenR + 7] & 0x80 == 0 { throw ScriptError.invalidSignatureEncoding }
}
