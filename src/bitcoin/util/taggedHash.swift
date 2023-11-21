import Foundation
import ECCHelper

func taggedHash(tag: String, payload: Data) -> Data {
    let tagHash = sha256(tag.data(using: .utf8)!)
    return sha256(tagHash + tagHash + payload)
}
