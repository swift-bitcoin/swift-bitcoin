import Foundation
import ECCHelper
import CryptoKit

func taggedHash(tag: String, payload: Data) -> Data {
    let tagHash = Data(SHA256.hash(data: tag.data(using: .utf8)!))
    return Data(SHA256.hash(data: tagHash + tagHash + payload))
}
