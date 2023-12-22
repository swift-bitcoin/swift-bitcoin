import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Crypto)
import Crypto
#endif

func hmacSHA512(_ key: Data, data: Data) -> Data {
    var hmac = HMAC<SHA512>(key: .init(data: key))
    hmac.update(data: data)
    return Data(hmac.finalize())
}

func hmacSHA512(_ key: String, data: Data) -> Data {
    hmacSHA512(key.data(using: .ascii)!, data: data)
}
