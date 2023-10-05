import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Crypto)
import Crypto
#endif

func hash256(_ data: Data) -> Data {
    let digest = SHA256.hash(data: sha256(data))
    return Data(digest)
}
