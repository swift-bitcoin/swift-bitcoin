import Foundation
import Crypto

public enum PBKDF2Error: Error {
    case invalidInput
    case derivedKeyTooLong
}

/// Implementation of the Password-Based Key Derivation Function Version 2 (PBKDF2)  used by BIP39 seed generation from mnemonic.
///
/// See [RFC2898](https://www.ietf.org/rfc/rfc2898.txt) for more information.
///
public struct PBKDF2<H: HashFunction> {

    /// S
    private let salt: Data

    /// c
    private let iterations: Int

    /// l
    private let numBlocks: Int

    /// keyLength
    private let dkLen: Int
    private let password: Data

    /// Creates an instance without performing any calculations.
    /// - Parameters:
    ///   - password: The password.
    ///   - salt: The salt.
    ///   - iterations: Iteration count, a positive integer.
    ///   - keyLength: Intended length of derived key.
    public init(password: Data, salt: Data, iterations: Int = 4096, keyLength: Int? = nil) throws(PBKDF2Error) {
        precondition(iterations > 0)

        guard iterations > 0 && !salt.isEmpty else {
            throw .invalidInput
        }

        dkLen = keyLength ?? H.Digest.byteCount
        let keyLengthFinal = Double(dkLen)
        let hLen = Double(H.Digest.byteCount)
        if keyLengthFinal > (pow(2, 32) - 1) * hLen {
            throw .derivedKeyTooLong
        }

        self.salt = salt
        self.iterations = iterations
        self.password = password

        // l = ceil(keyLength / hLen)
        numBlocks = Int(ceil(Double(keyLengthFinal) / hLen))
    }

    public func calculate() -> Array<UInt8> {
        var ret = Array<UInt8>()
        ret.reserveCapacity(numBlocks * H.Digest.byteCount)
        for i in 1 ... numBlocks {
            // for each block T_i = U_1 ^ U_2 ^ ... ^ U_iter
            if let value = calculateBlock(salt, blockNum: i) {
                ret.append(contentsOf: value)
            }
        }
        return Array(ret.prefix(dkLen))
    }

    private func calculateBlock(_ salt: Data, blockNum: Int) -> Data? {
        // F (P, S, c, i) = U_1 \xor U_2 \xor ... \xor U_c
        // U_1 = PRF (P, S || INT (i))

        func ARR(_ i: Int) -> Array<UInt8> {
            // `i.bytes()` is slower
            var inti = Array<UInt8>(repeating: 0, count: 4)
            inti[0] = UInt8((i >> 24) & 0xff)
            inti[1] = UInt8((i >> 16) & 0xff)
            inti[2] = UInt8((i >> 8) & 0xff)
            inti[3] = UInt8(i & 0xff)
            return inti
        }

        let hmacPassword = HMAC<H>(key: .init(data: password))
        var hmac = hmacPassword
        hmac.update(data: salt + ARR(blockNum))
        let u1 = Data(hmac.finalize())

        var u = u1
        var ret = u
        if iterations > 1 {
            // U_2 = PRF (P, U_1)
            // U_c = PRF (P, U_{c-1})
            for _ in 2 ... iterations {
                var hmac = hmacPassword
                hmac.update(data: u)
                u = Data(hmac.finalize())
                for x in 0 ..< ret.count {
                    ret[x] = ret[x] ^ u[x]
                }
            }
        }
        return ret
    }
}
