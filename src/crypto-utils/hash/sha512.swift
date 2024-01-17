import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Crypto)
import Crypto
#endif

public func sha512(_ data: Data) -> Data {
    Data(SHA512.hash(data: data))
}
