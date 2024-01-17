import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Crypto)
import Crypto
#endif

public func sha1(_ data: Data) -> Data {
    Data(Insecure.SHA1.hash(data: data))
}
