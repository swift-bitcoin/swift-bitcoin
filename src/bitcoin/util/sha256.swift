import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Crypto)
import Crypto
#endif

func sha256(_ data: Data) -> Data {
    Data(SHA256.hash(data: data))
}
