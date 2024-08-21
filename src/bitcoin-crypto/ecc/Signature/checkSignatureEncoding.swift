import Foundation

// TODO: Move this function into Signature struct somehow (use in initializer).

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
public func checkSignatureEncoding(_ sig: Data) -> Bool {
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
    if sig.count < 9 { return false }
    if sig.count > 73 { return false }

    let start = sig.startIndex

    // A signature is of type 0x30 (compound).
    if sig[start] != 0x30 { return false }

    // Make sure the length covers the entire signature.
    if sig[start + 1] != sig.count - 3 { return false }

    // Extract the length of the R element.
    let lenR = Int(sig[start + 3])

    // Make sure the length of the S element is still inside the signature.
    if 5 + lenR >= sig.count { return false }

    // Extract the length of the S element.
    let lenS = Int(sig[start + 5 + lenR])

    // Verify that the length of the signature matches the sum of the length
    // of the elements.
    if lenR + lenS + 7 != sig.count { return false }

    // Check whether the R element is an integer.
    if sig[start + 2] != 0x02 { return false }

    // Zero-length integers are not allowed for R.
    if lenR == 0 { return false }

    // Negative numbers are not allowed for R.
    if sig[start + 4] & 0x80 != 0 { return false }

    // Null bytes at the start of R are not allowed, unless R would
    // otherwise be interpreted as a negative number.
    if lenR > 1 && sig[start + 4] == 0x00 && sig[start + 5] & 0x80 == 0 { return false }

    // Check whether the S element is an integer.
    if sig[start + lenR + 4] != 0x02 { return false }

    // Zero-length integers are not allowed for S.
    if lenS == 0 { return false }

    // Negative numbers are not allowed for S.
    if sig[start + lenR + 6] & 0x80 != 0 { return false }

    // Null bytes at the start of S are not allowed, unless S would otherwise be
    // interpreted as a negative number.
    if lenS > 1 && sig[start + lenR + 6] == 0x00 && sig[start + lenR + 7] & 0x80 == 0 { return false }
    return true
}
